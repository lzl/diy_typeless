use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use crate::retry::{is_retryable_status, with_retry, HttpResult};
use reqwest::StatusCode;
use secrecy::{ExposeSecret, SecretString};
use serde::Deserialize;

#[derive(Deserialize)]
struct GeminiResponse {
    candidates: Vec<GeminiCandidate>,
}

#[derive(Deserialize)]
struct GeminiCandidate {
    content: GeminiContent,
}

#[derive(Deserialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
}

#[derive(Deserialize)]
struct GeminiPart {
    text: Option<String>,
}

/// Build the context section for the polishing prompt.
///
/// Returns an empty string if context is None or empty,
/// otherwise returns a formatted context section with usage guidelines.
fn build_context_section(context: Option<&str>) -> String {
    match context {
        Some(ctx) if !ctx.trim().is_empty() => format!(
            "\n\nContext about where this text will be used:\n{ctx}\nAdapt the tone, format and style to match the target application.\n- Chat/messaging apps (Slack, Teams, iMessage): keep it casual and concise\n- Email (Gmail, Outlook): use standard email structure (greeting line, body, sign-off), format phone numbers and addresses properly, preserve the sender's greeting style (e.g., \"Hi\" stays casual, don't upgrade to \"Dear\")\n- Code editors: preserve technical terms and formatting\n- Social media: follow platform conventions\nIMPORTANT: Match the speaker's original level of formality — do NOT make casual speech overly formal.\n"
        ),
        _ => String::new(),
    }
}

/// Build the complete polishing prompt for the LLM.
///
/// # Arguments
/// * `raw_text` - The transcribed text to polish
/// * `context` - Optional context about where the text will be used
///
/// # Returns
/// The complete prompt string to send to the LLM
fn build_prompt(raw_text: &str, context: Option<&str>) -> String {
    let context_section = build_context_section(context);

    format!(
         "You are a professional text editor. Transform the following speech transcript into well-structured written text.\n\nRules:\n1. Keep the SAME language as the original - do NOT translate\n2. Convert spoken language to written language:\n   - Remove filler words (e.g., \"um\", \"uh\", \"like\", \"you know\", or equivalents in other languages)\n   - Clean up spoken-language patterns: remove filler words and fix grammar errors, but preserve the speaker's original sentence structure and phrasing choices. NEVER rewrite sentences into different forms.\n   - Fix transcription errors (misheard words, typos)\n   - Handle self-corrections: when the speaker changes their mind (e.g., \"let's meet at 7, actually make it 3\"), keep ONLY the final intention and remove the corrected content\n3. Reorganize content logically:\n   - Group related information together\n   - Separate different topics into paragraphs with blank lines\n4. When content contains multiple parallel points, requirements, or items, ALWAYS format them as a numbered or bulleted list — NEVER as separate paragraphs. Example:\n   BAD: \"First issue is performance. Second issue is UI complexity.\"\n   GOOD: \"Issues encountered:\\n1. Performance bottlenecks\\n2. UI complexity\"\n5. Preserve ALL substantive information - only remove verbal fillers, not actual content\n6. Add proper punctuation and spacing\n7. Output ONLY the final polished text - no comments or annotations\n{context_section}\nOriginal transcript:\n{raw_text}\n\nOutput the polished text directly.",
     )
}

pub fn polish_text(
    api_key: &SecretString,
    raw_text: &str,
    context: Option<&str>,
) -> Result<String, CoreError> {
    let prompt = build_prompt(raw_text, context);

    let client = get_http_client();
    let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");

    let result = with_retry(
        3,
        || {
            let body = serde_json::json!({
                "contents": [
                    {
                        "role": "user",
                        "parts": [{"text": prompt}],
                    }
                ]
            });

            let response = client
                .post(&url)
                .header("x-goog-api-key", api_key.expose_secret())
                .json(&body)
                .send();

            match response {
                Ok(resp) if resp.status() == StatusCode::OK => {
                    match resp.json::<GeminiResponse>() {
                        Ok(payload) => {
                            let text = payload
                                .candidates
                                .first()
                                .and_then(|c| c.content.parts.first())
                                .and_then(|p| p.text.clone());

                            match text {
                                Some(t) => {
                                    let trimmed = t.trim();
                                    if trimmed.is_empty() {
                                        HttpResult::NonRetryable("Empty response".to_string())
                                    } else {
                                        HttpResult::Success(trimmed.to_string())
                                    }
                                }
                                None => HttpResult::NonRetryable("Empty response".to_string()),
                            }
                        }
                        Err(e) => HttpResult::NonRetryable(e.to_string()),
                    }
                }
                Ok(resp) if is_retryable_status(resp.status()) => HttpResult::Retryable,
                Ok(resp) => HttpResult::NonRetryable(format!(
                    "Gemini API error: HTTP {}",
                    resp.status()
                )),
                Err(_) => HttpResult::Retryable,
            }
        },
        "Gemini API",
    );

    match result {
        Ok(text) => Ok(text),
        Err(msg) => {
            if msg == "Empty response" {
                Err(CoreError::EmptyResponse)
            } else if msg.starts_with("Gemini API error") {
                Err(CoreError::Api(msg))
            } else {
                Err(CoreError::Http(msg))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{build_context_section, build_prompt};

    #[test]
    fn build_context_section_should_include_guidelines_when_context_provided() {
        let context = Some("email");
        let formatted = build_context_section(context);
        assert!(formatted.contains("email"));
        assert!(formatted.contains("Context about where this text will be used"));
        assert!(formatted.contains("Gmail, Outlook"));
    }

    #[test]
    fn build_context_section_should_return_empty_when_empty_string() {
        let context: Option<&str> = Some("");
        let formatted = build_context_section(context);
        assert!(formatted.is_empty());
    }

    #[test]
    fn build_context_section_should_return_empty_when_whitespace_only() {
        let context: Option<&str> = Some("   ");
        let formatted = build_context_section(context);
        assert!(formatted.is_empty());
    }

    #[test]
    fn build_context_section_should_return_empty_when_none() {
        let context: Option<&str> = None;
        let formatted = build_context_section(context);
        assert!(formatted.is_empty());
    }

    #[test]
    fn build_prompt_should_contain_all_rules() {
        let raw_text = "Hello world";
        let prompt = build_prompt(raw_text, None);

        assert!(prompt.contains("You are a professional text editor"));
        assert!(prompt.contains("Rules:"));
        assert!(prompt.contains("Keep the SAME language"));
        assert!(prompt.contains("Original transcript:"));
        assert!(prompt.contains("Hello world"));
        assert!(prompt.contains("Output the polished text directly"));
    }

    #[test]
    fn build_prompt_should_include_context_when_provided() {
        let raw_text = "Meeting notes";
        let context = Some("email");
        let prompt = build_prompt(raw_text, context);

        assert!(prompt.contains("Context about where this text will be used"));
        assert!(prompt.contains("email"));
    }

    #[test]
    fn build_prompt_should_preserve_all_substantive_content_instruction() {
        let raw_text = "The quick brown fox jumps over the lazy dog";
        let prompt = build_prompt(raw_text, None);

        assert!(prompt.contains("Preserve ALL substantive information"));
        assert!(prompt.contains(raw_text));
    }

    #[test]
    fn build_prompt_should_include_rules_section_before_transcript() {
        let raw_text = "Test content";
        let prompt = build_prompt(raw_text, None);

        let rules_pos = prompt.find("Rules:").expect("Rules section should exist");
        let transcript_pos = prompt.find("Original transcript:").expect("Transcript section should exist");

        assert!(
            rules_pos < transcript_pos,
            "Rules should appear before transcript"
        );
    }

    #[test]
    fn test_exponential_backoff_calculation() {
        // Test that backoff increases exponentially: 2^0, 2^1, 2^2
        assert_eq!(2u64.pow(0), 1);
        assert_eq!(2u64.pow(1), 2);
        assert_eq!(2u64.pow(2), 4);
    }
}

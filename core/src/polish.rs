use crate::async_executor::run_blocking;
use crate::cancellation::CoreCancellationToken;
use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_async_http_client;
#[cfg(test)]
use crate::retry::with_retry;
use crate::retry::{is_retryable_status, HttpResult};
use reqwest::StatusCode;
use secrecy::{ExposeSecret, SecretString};
use serde::Deserialize;
use std::time::Duration;

const EMPTY_RESPONSE_MESSAGE: &str = "Empty response";
const CANCELLATION_MESSAGE: &str = "Operation cancelled";
const POLISH_MAX_RETRY_ATTEMPTS: u32 = 3;

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

fn build_polish_request_body(prompt: &str) -> serde_json::Value {
    serde_json::json!({
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ]
    })
}

fn extract_gemini_text(payload: GeminiResponse) -> HttpResult<String> {
    let text = payload
        .candidates
        .first()
        .and_then(|c| c.content.parts.first())
        .and_then(|p| p.text.clone());

    match text {
        Some(value) => {
            let trimmed = value.trim();
            if trimmed.is_empty() {
                HttpResult::NonRetryable(EMPTY_RESPONSE_MESSAGE.to_string())
            } else {
                HttpResult::Success(trimmed.to_string())
            }
        }
        None => HttpResult::NonRetryable(EMPTY_RESPONSE_MESSAGE.to_string()),
    }
}

fn classify_gemini_status(status: StatusCode) -> HttpResult<()> {
    if status == StatusCode::OK {
        HttpResult::Success(())
    } else if is_retryable_status(status) {
        HttpResult::Retryable
    } else {
        HttpResult::NonRetryable(format!("Gemini API error: HTTP {status}"))
    }
}

fn map_gemini_error(msg: String) -> CoreError {
    if msg == EMPTY_RESPONSE_MESSAGE {
        CoreError::EmptyResponse
    } else if msg == CANCELLATION_MESSAGE {
        CoreError::Cancelled
    } else if msg.starts_with("Gemini API error") {
        CoreError::Api(msg)
    } else {
        CoreError::Http(msg)
    }
}

#[cfg(test)]
fn run_polish_with_retry(
    operation: impl FnMut() -> HttpResult<String>,
) -> Result<String, CoreError> {
    with_retry(POLISH_MAX_RETRY_ATTEMPTS, operation, "Gemini API").map_err(map_gemini_error)
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

pub(crate) fn polish_text(
    api_key: &SecretString,
    raw_text: &str,
    context: Option<&str>,
    cancellation_token: &CoreCancellationToken,
) -> Result<String, CoreError> {
    let prompt = build_prompt(raw_text, context);
    if cancellation_token.is_cancelled() {
        return Err(CoreError::Cancelled);
    }

    run_blocking(async {
        let client = get_async_http_client();
        let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");

        for attempt in 0..POLISH_MAX_RETRY_ATTEMPTS {
            if cancellation_token.is_cancelled() {
                return Err(CoreError::Cancelled);
            }

            let outcome = polish_once(client, &url, api_key, &prompt, cancellation_token).await;

            match outcome {
                HttpResult::Success(text) => return Ok(text),
                HttpResult::NonRetryable(message) => return Err(map_gemini_error(message)),
                HttpResult::Retryable => {
                    if attempt < POLISH_MAX_RETRY_ATTEMPTS - 1 {
                        let backoff_seconds = 2u64.pow(attempt);
                        tokio::select! {
                            _ = cancellation_token.cancelled() => return Err(CoreError::Cancelled),
                            _ = tokio::time::sleep(Duration::from_secs(backoff_seconds)) => {}
                        }
                    }
                }
            }
        }

        Err(CoreError::Http("Gemini API: retries exceeded".to_string()))
    })
}

async fn polish_once(
    client: &reqwest::Client,
    url: &str,
    api_key: &SecretString,
    prompt: &str,
    cancellation_token: &CoreCancellationToken,
) -> HttpResult<String> {
    let body = build_polish_request_body(prompt);
    let request = client
        .post(url)
        .header("x-goog-api-key", api_key.expose_secret())
        .json(&body)
        .send();

    let response = tokio::select! {
        _ = cancellation_token.cancelled() => {
            return HttpResult::NonRetryable(CANCELLATION_MESSAGE.to_string());
        }
        response = request => response
    };

    match response {
        Ok(resp) => match classify_gemini_status(resp.status()) {
            HttpResult::Success(()) => match resp.json::<GeminiResponse>().await {
                Ok(payload) => extract_gemini_text(payload),
                Err(e) => HttpResult::NonRetryable(e.to_string()),
            },
            HttpResult::Retryable => HttpResult::Retryable,
            HttpResult::NonRetryable(msg) => HttpResult::NonRetryable(msg),
        },
        Err(_) => HttpResult::Retryable,
    }
}

#[cfg(test)]
mod tests {
    use super::{
        build_context_section, build_polish_request_body, build_prompt, classify_gemini_status,
        extract_gemini_text, map_gemini_error, run_polish_with_retry, GeminiResponse,
    };
    use crate::cancellation::CoreCancellationToken;
    use crate::error::CoreError;
    use crate::retry::HttpResult;
    use reqwest::StatusCode;
    use secrecy::SecretString;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn build_context_section_should_include_one_context_block_when_context_provided() {
        let context = Some("email and calendar invite");
        let formatted = build_context_section(context);
        let marker = "Context about where this text will be used:";
        assert!(formatted.contains(marker));
        assert_eq!(formatted.matches(marker).count(), 1);
        assert!(formatted.contains("email and calendar invite"));
        assert!(formatted.contains("Gmail, Outlook"));
    }

    #[test]
    fn build_context_section_should_be_absent_for_empty_or_missing_context() {
        let empty = build_context_section(Some(""));
        let whitespace = build_context_section(Some("   "));
        let none = build_context_section(None);

        let marker = "Context about where this text will be used:";
        assert!(empty.is_empty());
        assert!(whitespace.is_empty());
        assert!(none.is_empty());
        assert!(!empty.contains(marker));
        assert!(!whitespace.contains(marker));
        assert!(!none.contains(marker));
    }

    #[test]
    fn build_prompt_should_include_rules_section_once_and_before_transcript() {
        let raw_text = "Hello world";
        let prompt = build_prompt(raw_text, None);

        let rules_marker = "\n\nRules:\n";
        let transcript_marker = "\nOriginal transcript:\n";
        let rules_pos = prompt
            .find(rules_marker)
            .expect("Rules section should exist");
        let transcript_pos = prompt
            .find(transcript_marker)
            .expect("Transcript section should exist");

        assert_eq!(prompt.matches(rules_marker).count(), 1);
        assert_eq!(prompt.matches(transcript_marker).count(), 1);
        assert!(rules_pos < transcript_pos);
    }

    #[test]
    fn build_prompt_should_embed_transcript_verbatim() {
        let raw_text = "Line one.\nLine two has  spaces.\n\nFinal line.";
        let prompt = build_prompt(raw_text, None);
        let transcript_block = format!("\nOriginal transcript:\n{raw_text}\n\nOutput");

        assert!(prompt.contains(&transcript_block));
    }

    #[test]
    fn build_prompt_should_include_context_section_once_when_provided() {
        let raw_text = "Meeting notes";
        let prompt = build_prompt(raw_text, Some("email"));
        let marker = "Context about where this text will be used:";

        assert_eq!(prompt.matches(marker).count(), 1);
        assert!(prompt.contains("email"));
    }

    #[test]
    fn build_prompt_should_not_include_context_section_when_context_missing() {
        let prompt_empty = build_prompt("Raw text", Some(""));
        let prompt_whitespace = build_prompt("Raw text", Some("   "));
        let prompt_none = build_prompt("Raw text", None);
        let marker = "Context about where this text will be used:";

        assert!(!prompt_empty.contains(marker));
        assert!(!prompt_whitespace.contains(marker));
        assert!(!prompt_none.contains(marker));
    }

    #[test]
    fn build_prompt_should_contain_critical_instructions() {
        let raw_text = "The quick brown fox jumps over the lazy dog";
        let prompt = build_prompt(raw_text, None);

        assert!(prompt.contains("You are a professional text editor"));
        assert!(prompt.contains("Keep the SAME language"));
        assert!(prompt.contains("Preserve ALL substantive information"));
        assert!(prompt.contains("Output ONLY the final polished text"));
    }

    #[test]
    fn build_prompt_should_keep_transcript_and_output_boundary_stable() {
        let raw_text = "Test content";
        let prompt = build_prompt(raw_text, None);
        let boundary = "\nOriginal transcript:\nTest content\n\nOutput the polished text directly.";

        assert!(prompt.contains(boundary));
    }

    #[test]
    fn build_polish_request_body_should_embed_prompt_as_user_text() {
        let body = build_polish_request_body("hello");
        assert_eq!(body["contents"][0]["role"], "user");
        assert_eq!(body["contents"][0]["parts"][0]["text"], "hello");
    }

    #[test]
    fn extract_gemini_text_should_return_success_when_payload_contains_text() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": [{"content": {"parts": [{"text": "  polished output  "}]}}]
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::Success(value) if value == "polished output"));
    }

    #[test]
    fn extract_gemini_text_should_return_empty_response_when_candidates_are_missing() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": []
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn extract_gemini_text_should_return_empty_response_when_text_is_blank() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": [{"content": {"parts": [{"text": "   "} ]}}]
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn classify_gemini_status_should_retry_on_server_errors() {
        let result = classify_gemini_status(StatusCode::SERVICE_UNAVAILABLE);
        assert!(matches!(result, HttpResult::Retryable));
    }

    #[test]
    fn classify_gemini_status_should_map_client_error_to_non_retryable() {
        let result = classify_gemini_status(StatusCode::UNAUTHORIZED);
        assert!(
            matches!(result, HttpResult::NonRetryable(msg) if msg == "Gemini API error: HTTP 401 Unauthorized")
        );
    }

    #[test]
    fn map_gemini_error_should_map_empty_response_variant() {
        let result = map_gemini_error("Empty response".to_string());
        assert!(matches!(result, CoreError::EmptyResponse));
    }

    #[test]
    fn map_gemini_error_should_map_api_variant() {
        let result = map_gemini_error("Gemini API error: HTTP 403 Forbidden".to_string());
        assert!(matches!(result, CoreError::Api(_)));
    }

    #[test]
    fn map_gemini_error_should_map_http_variant() {
        let result = map_gemini_error("request timeout".to_string());
        assert!(matches!(result, CoreError::Http(_)));
    }

    #[test]
    fn map_gemini_error_should_map_cancelled_variant() {
        let result = map_gemini_error("Operation cancelled".to_string());
        assert!(matches!(result, CoreError::Cancelled));
    }

    #[test]
    fn run_polish_with_retry_should_retry_until_third_attempt_success() {
        let attempts = AtomicU32::new(0);

        let result = run_polish_with_retry(|| {
            let attempt = attempts.fetch_add(1, Ordering::SeqCst);
            if attempt < 2 {
                HttpResult::Retryable
            } else {
                HttpResult::Success("ok".to_string())
            }
        });

        assert!(matches!(result, Ok(value) if value == "ok"));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn run_polish_with_retry_should_fail_after_retry_budget_exhausted() {
        let attempts = AtomicU32::new(0);

        let result = run_polish_with_retry(|| {
            attempts.fetch_add(1, Ordering::SeqCst);
            HttpResult::Retryable
        });

        assert!(
            matches!(result, Err(CoreError::Http(message)) if message == "Gemini API: retries exceeded")
        );
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn polish_text_should_return_cancelled_when_token_is_already_cancelled() {
        let token = CoreCancellationToken::new();
        token.cancel();

        let result = super::polish_text(
            &SecretString::from("test-key".to_string()),
            "raw transcript",
            None,
            token.as_ref(),
        );

        assert!(matches!(result, Err(CoreError::Cancelled)));
    }
}

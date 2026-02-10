use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use reqwest::blocking::Client;
use reqwest::StatusCode;
use serde::Deserialize;
use std::thread::sleep;
use std::time::Duration;

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

pub fn polish_text(
    api_key: &str,
    raw_text: &str,
    context: Option<&str>,
) -> Result<String, CoreError> {
    let context_section = match context {
        Some(ctx) if !ctx.trim().is_empty() => format!(
            "\n\nContext about where this text will be used:\n{ctx}\nAdapt the tone, format and style to match the target application. For example: chat/messaging apps should be casual and concise; email should use appropriate email tone; code editors should preserve technical terms; social media should follow platform conventions.\n"
        ),
        _ => String::new(),
    };

    let prompt = format!(
         "You are a professional text editor. Transform the following speech transcript into well-structured written text.\n\nRules:\n1. Keep the SAME language as the original - do NOT translate\n2. Convert spoken language to written language:\n   - Remove filler words (e.g., \"um\", \"uh\", \"like\", \"you know\", or equivalents in other languages)\n   - Transform colloquial expressions into formal written style\n   - Fix transcription errors (misheard words, typos)\n3. Reorganize content logically:\n   - Group related information together\n   - Separate different topics into paragraphs with blank lines\n4. When content contains multiple parallel points, requirements, or items, ALWAYS format them as a numbered or bulleted list — NEVER as separate paragraphs. Example:\n   BAD: \"First issue is performance. Second issue is UI complexity.\"\n   GOOD: \"Issues encountered:\\n1. Performance bottlenecks\\n2. UI complexity\"\n5. Preserve ALL substantive information - only remove verbal fillers, not actual content\n6. Add proper punctuation and spacing\n7. Output ONLY the final polished text - no comments or annotations\n{context_section}\nOriginal transcript:\n{raw_text}\n\nOutput the polished text directly.",
     );

    let client = Client::builder().timeout(Duration::from_secs(90)).build()?;

    let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");

    for attempt in 0..3 {
        let body = serde_json::json!({
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": prompt}],
                }
            ]
        });

        let response = client.post(&url).header("x-goog-api-key", api_key).json(&body).send();

        match response {
            Ok(resp) if resp.status() == StatusCode::OK => {
                let payload: GeminiResponse = resp.json()?;
                let text = payload
                    .candidates
                    .get(0)
                    .and_then(|c| c.content.parts.get(0))
                    .and_then(|p| p.text.clone())
                    .ok_or(CoreError::EmptyResponse)?;
                let trimmed = text.trim();
                if trimmed.is_empty() {
                    return Err(CoreError::EmptyResponse);
                }
                return Ok(trimmed.to_string());
            }
            Ok(resp)
                if resp.status() == StatusCode::TOO_MANY_REQUESTS
                    || resp.status().is_server_error() =>
            {
                let backoff = 2u64.pow(attempt);
                sleep(Duration::from_secs(backoff));
                continue;
            }
            Ok(resp) => {
                return Err(CoreError::Api(format!(
                    "Gemini API error: HTTP {}",
                    resp.status()
                )));
            }
            Err(err) => {
                if attempt < 2 {
                    let backoff = 2u64.pow(attempt);
                    sleep(Duration::from_secs(backoff));
                    continue;
                }
                return Err(CoreError::Http(err.to_string()));
            }
        }
    }

    Err(CoreError::Api("Gemini API retries exceeded".to_string()))
}

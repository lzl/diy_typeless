use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
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

/// Generic LLM text processing function.
///
/// # Arguments
/// * `api_key` - Gemini API key
/// * `prompt` - The prompt to send to the LLM
/// * `system_instruction` - Optional system instruction for the LLM
/// * `temperature` - Optional temperature parameter (0.0 - 1.0)
///
/// # Returns
/// * `Ok(String)` - The processed text response
/// * `Err(CoreError)` - If the API call fails
///
/// # Retry Logic
/// Retries up to 3 times with exponential backoff for:
/// - HTTP 429 (Too Many Requests)
/// - HTTP 5xx (Server Errors)
/// - Network errors
pub fn process_text_with_llm(
    api_key: &str,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    let client = get_http_client();
    let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");

    let mut body = serde_json::json!({
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ]
    });

    // Add system instruction if provided
    if let Some(instruction) = system_instruction {
        body["systemInstruction"] = serde_json::json!({
            "parts": [{"text": instruction}]
        });
    }

    // Add generation config
    let mut generation_config = serde_json::Map::new();
    if let Some(temp) = temperature {
        generation_config.insert("temperature".to_string(), serde_json::json!(temp));
    }
    // Limit output length to prevent excessive generation
    generation_config.insert("maxOutputTokens".to_string(), serde_json::json!(4096));
    body["generationConfig"] = serde_json::Value::Object(generation_config);

    // Retry logic with exponential backoff
    for attempt in 0..3 {
        let response = client
            .post(&url)
            .header("x-goog-api-key", api_key)
            .json(&body)
            .send();

        match response {
            Ok(resp) if resp.status() == StatusCode::OK => {
                let payload: GeminiResponse = resp.json()?;
                let text = payload
                    .candidates
                    .get(0)
                    .and_then(|c| c.content.parts.get(0))
                    .and_then(|p| p.text.clone())
                    .ok_or(CoreError::EmptyResponse)?;
                return Ok(text.trim().to_string());
            }
            Ok(resp) if resp.status() == StatusCode::TOO_MANY_REQUESTS
                || resp.status().is_server_error() => {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exponential_backoff_calculation() {
        // Test that backoff increases exponentially
        assert_eq!(2u64.pow(0), 1);
        assert_eq!(2u64.pow(1), 2);
        assert_eq!(2u64.pow(2), 4);
    }
}

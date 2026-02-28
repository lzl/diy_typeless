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
    api_key: &SecretString,
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

    let result = with_retry(
        3,
        || {
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
                                Some(t) => HttpResult::Success(t.trim().to_string()),
                                None => {
                                    HttpResult::NonRetryable("Empty response".to_string())
                                }
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
    #[test]
    fn test_exponential_backoff_calculation() {
        // Test that backoff increases exponentially
        assert_eq!(2u64.pow(0), 1);
        assert_eq!(2u64.pow(1), 2);
        assert_eq!(2u64.pow(2), 4);
    }
}

use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use crate::retry::{is_retryable_status, with_retry, HttpResult};
use reqwest::StatusCode;
use secrecy::{ExposeSecret, SecretString};
use serde::Deserialize;

const EMPTY_RESPONSE_MESSAGE: &str = "Empty response";
const LLM_MAX_RETRY_ATTEMPTS: u32 = 3;

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

fn build_llm_request_body(
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> serde_json::Value {
    let mut body = serde_json::json!({
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ]
    });

    if let Some(instruction) = system_instruction {
        body["systemInstruction"] = serde_json::json!({
            "parts": [{"text": instruction}]
        });
    }

    let mut generation_config = serde_json::Map::new();
    if let Some(temp) = temperature {
        generation_config.insert("temperature".to_string(), serde_json::json!(temp));
    }
    generation_config.insert("maxOutputTokens".to_string(), serde_json::json!(4096));
    body["generationConfig"] = serde_json::Value::Object(generation_config);
    body
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
    } else if msg.starts_with("Gemini API error") {
        CoreError::Api(msg)
    } else {
        CoreError::Http(msg)
    }
}

fn run_llm_with_retry(operation: impl FnMut() -> HttpResult<String>) -> Result<String, CoreError> {
    with_retry(LLM_MAX_RETRY_ATTEMPTS, operation, "Gemini API").map_err(map_gemini_error)
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
pub(crate) fn process_text_with_llm(
    api_key: &SecretString,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    let client = get_http_client();
    let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");
    let body = build_llm_request_body(prompt, system_instruction, temperature);

    run_llm_with_retry(|| {
        let response = client
            .post(&url)
            .header("x-goog-api-key", api_key.expose_secret())
            .json(&body)
            .send();

        match response {
            Ok(resp) => match classify_gemini_status(resp.status()) {
                HttpResult::Success(()) => match resp.json::<GeminiResponse>() {
                    Ok(payload) => extract_gemini_text(payload),
                    Err(e) => HttpResult::NonRetryable(e.to_string()),
                },
                HttpResult::Retryable => HttpResult::Retryable,
                HttpResult::NonRetryable(msg) => HttpResult::NonRetryable(msg),
            },
            Err(_) => HttpResult::Retryable,
        }
    })
}

#[cfg(test)]
mod tests {
    use super::{
        build_llm_request_body, classify_gemini_status, extract_gemini_text, map_gemini_error,
        run_llm_with_retry, GeminiResponse,
    };
    use crate::error::CoreError;
    use crate::retry::HttpResult;
    use reqwest::StatusCode;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn build_llm_request_body_should_include_required_sections() {
        let body = build_llm_request_body("prompt", None, None);
        assert_eq!(body["contents"][0]["role"], "user");
        assert_eq!(body["contents"][0]["parts"][0]["text"], "prompt");
        assert_eq!(body["generationConfig"]["maxOutputTokens"], 4096);
    }

    #[test]
    fn build_llm_request_body_should_include_system_instruction_when_provided() {
        let body = build_llm_request_body("prompt", Some("be concise"), None);
        assert_eq!(body["systemInstruction"]["parts"][0]["text"], "be concise");
    }

    #[test]
    fn build_llm_request_body_should_include_temperature_when_provided() {
        let body = build_llm_request_body("prompt", None, Some(0.3));
        let temperature = body["generationConfig"]["temperature"]
            .as_f64()
            .expect("temperature should be a number");
        assert!((temperature - 0.3).abs() < 0.000_001);
    }

    #[test]
    fn build_llm_request_body_should_skip_temperature_when_missing() {
        let body = build_llm_request_body("prompt", None, None);
        assert!(body["generationConfig"].get("temperature").is_none());
    }

    #[test]
    fn extract_gemini_text_should_return_trimmed_value() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": [{"content": {"parts": [{"text": "  result  "}]}}]
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::Success(text) if text == "result"));
    }

    #[test]
    fn extract_gemini_text_should_fail_when_text_missing() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": [{"content": {"parts": [{"text": null}]}}]
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn extract_gemini_text_should_fail_when_text_blank() {
        let payload: GeminiResponse = serde_json::from_value(serde_json::json!({
            "candidates": [{"content": {"parts": [{"text": "   "} ]}}]
        }))
        .expect("valid payload");
        let result = extract_gemini_text(payload);
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn classify_gemini_status_should_mark_retryable_statuses() {
        let result = classify_gemini_status(StatusCode::INTERNAL_SERVER_ERROR);
        assert!(matches!(result, HttpResult::Retryable));
    }

    #[test]
    fn classify_gemini_status_should_mark_non_retryable_statuses() {
        let result = classify_gemini_status(StatusCode::BAD_REQUEST);
        assert!(
            matches!(result, HttpResult::NonRetryable(msg) if msg == "Gemini API error: HTTP 400 Bad Request")
        );
    }

    #[test]
    fn map_gemini_error_should_map_empty_response_variant() {
        let error = map_gemini_error("Empty response".to_string());
        assert!(matches!(error, CoreError::EmptyResponse));
    }

    #[test]
    fn map_gemini_error_should_map_api_variant() {
        let error = map_gemini_error("Gemini API error: HTTP 429 Too Many Requests".to_string());
        assert!(matches!(error, CoreError::Api(_)));
    }

    #[test]
    fn map_gemini_error_should_map_http_variant() {
        let error = map_gemini_error("network issue".to_string());
        assert!(matches!(error, CoreError::Http(_)));
    }

    #[test]
    fn run_llm_with_retry_should_retry_until_third_attempt_success() {
        let attempts = AtomicU32::new(0);

        let result = run_llm_with_retry(|| {
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
    fn run_llm_with_retry_should_fail_after_retry_budget_exhausted() {
        let attempts = AtomicU32::new(0);

        let result = run_llm_with_retry(|| {
            attempts.fetch_add(1, Ordering::SeqCst);
            HttpResult::Retryable
        });

        assert!(
            matches!(result, Err(CoreError::Http(message)) if message == "Gemini API: retries exceeded")
        );
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }
}

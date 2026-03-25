use crate::cancellation::{
    cancellation_requested, run_with_cancellation, worker_disconnected_message,
    CancellableOperationError, CancellationToken,
};
use crate::config::{GEMINI_API_URL, GEMINI_MODEL, OPENAI_API_URL, OPENAI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use crate::retry::{is_retryable_status, with_retry, with_retry_cancellable, HttpResult};
use crate::LlmProvider;
use reqwest::StatusCode;
use secrecy::{ExposeSecret, SecretString};
use serde::Deserialize;

const EMPTY_RESPONSE_MESSAGE: &str = "Empty response";
const CANCELLED_RESPONSE_MESSAGE: &str = "Operation cancelled";
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

#[derive(Deserialize)]
struct OpenAiResponse {
    choices: Vec<OpenAiChoice>,
}

#[derive(Deserialize)]
struct OpenAiChoice {
    message: OpenAiMessage,
}

#[derive(Deserialize)]
struct OpenAiMessage {
    content: Option<String>,
}

fn provider_api_name(provider: LlmProvider) -> &'static str {
    match provider {
        LlmProvider::GoogleAiStudio => "Gemini API",
        LlmProvider::Openai => "OpenAI API",
    }
}

fn build_llm_request_body(
    provider: LlmProvider,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> serde_json::Value {
    match provider {
        LlmProvider::GoogleAiStudio => {
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
        LlmProvider::Openai => {
            let mut messages = Vec::new();
            if let Some(instruction) = system_instruction {
                messages.push(serde_json::json!({
                    "role": "system",
                    "content": instruction,
                }));
            }
            messages.push(serde_json::json!({
                "role": "user",
                "content": prompt,
            }));

            let mut body = serde_json::json!({
                "model": OPENAI_MODEL,
                "messages": messages,
            });

            if let Some(temp) = temperature {
                body["temperature"] = serde_json::json!(temp);
            }

            body
        }
    }
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

fn extract_openai_text(payload: OpenAiResponse) -> HttpResult<String> {
    let text = payload
        .choices
        .first()
        .and_then(|choice| choice.message.content.clone());

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

fn classify_status(provider: LlmProvider, status: StatusCode) -> HttpResult<()> {
    if status == StatusCode::OK {
        HttpResult::Success(())
    } else if is_retryable_status(status) {
        HttpResult::Retryable
    } else {
        HttpResult::NonRetryable(format!("{} error: HTTP {status}", provider_api_name(provider)))
    }
}

fn map_provider_error(provider: LlmProvider, msg: String) -> CoreError {
    let api_error_prefix = format!("{} error: HTTP", provider_api_name(provider));
    if msg == EMPTY_RESPONSE_MESSAGE {
        CoreError::EmptyResponse
    } else if msg == CANCELLED_RESPONSE_MESSAGE {
        CoreError::Cancelled
    } else if msg.starts_with(&api_error_prefix) {
        CoreError::Api(msg)
    } else {
        CoreError::Http(msg)
    }
}

fn run_llm_with_retry(
    provider: LlmProvider,
    operation: impl FnMut() -> HttpResult<String>,
    cancellation_token: Option<&CancellationToken>,
) -> Result<String, CoreError> {
    let api_name = provider_api_name(provider);
    if let Some(token) = cancellation_token {
        with_retry_cancellable(LLM_MAX_RETRY_ATTEMPTS, operation, api_name, || {
            token.is_cancelled()
        })
        .map_err(|msg| map_provider_error(provider, msg))
    } else {
        with_retry(LLM_MAX_RETRY_ATTEMPTS, operation, api_name)
            .map_err(|msg| map_provider_error(provider, msg))
    }
}

fn execute_llm_request(
    provider: LlmProvider,
    client: &reqwest::blocking::Client,
    url: &str,
    api_key: &str,
    body: &serde_json::Value,
) -> HttpResult<String> {
    let request = match provider {
        LlmProvider::GoogleAiStudio => client.post(url).header("x-goog-api-key", api_key),
        LlmProvider::Openai => client.post(url).bearer_auth(api_key),
    };

    let response = request.json(body).send();

    match response {
        Ok(resp) => match classify_status(provider, resp.status()) {
            HttpResult::Success(()) => match provider {
                LlmProvider::GoogleAiStudio => match resp.json::<GeminiResponse>() {
                    Ok(payload) => extract_gemini_text(payload),
                    Err(e) => HttpResult::NonRetryable(e.to_string()),
                },
                LlmProvider::Openai => match resp.json::<OpenAiResponse>() {
                    Ok(payload) => extract_openai_text(payload),
                    Err(e) => HttpResult::NonRetryable(e.to_string()),
                },
            },
            HttpResult::Retryable => HttpResult::Retryable,
            HttpResult::NonRetryable(msg) => HttpResult::NonRetryable(msg),
        },
        Err(_) => HttpResult::Retryable,
    }
}

fn execute_llm_request_cancellable(
    provider: LlmProvider,
    client: &reqwest::blocking::Client,
    url: &str,
    api_key: &SecretString,
    body: &serde_json::Value,
    cancellation_token: Option<&CancellationToken>,
) -> HttpResult<String> {
    if cancellation_requested(cancellation_token) {
        return HttpResult::NonRetryable(CANCELLED_RESPONSE_MESSAGE.to_string());
    }

    if cancellation_token.is_none() {
        return execute_llm_request(provider, client, url, api_key.expose_secret(), body);
    }

    let worker_client = client.clone();
    let worker_url = url.to_string();
    let worker_api_key = api_key.expose_secret().to_string();
    let worker_body = body.clone();

    match run_with_cancellation(cancellation_token, move || {
        execute_llm_request(
            provider,
            &worker_client,
            &worker_url,
            &worker_api_key,
            &worker_body,
        )
    }) {
        Ok(result) => result,
        Err(CancellableOperationError::Cancelled) => {
            HttpResult::NonRetryable(CANCELLED_RESPONSE_MESSAGE.to_string())
        }
        Err(CancellableOperationError::WorkerDisconnected) => {
            HttpResult::NonRetryable(worker_disconnected_message().to_string())
        }
    }
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
    provider: LlmProvider,
    api_key: &SecretString,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    process_text_with_llm_with_cancellation(
        provider,
        api_key,
        prompt,
        system_instruction,
        temperature,
        None,
    )
}

pub(crate) fn process_text_with_llm_with_cancellation(
    provider: LlmProvider,
    api_key: &SecretString,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
    cancellation_token: Option<&CancellationToken>,
) -> Result<String, CoreError> {
    if cancellation_requested(cancellation_token) {
        return Err(CoreError::Cancelled);
    }

    let client = get_http_client();
    let url = match provider {
        LlmProvider::GoogleAiStudio => format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent"),
        LlmProvider::Openai => format!("{OPENAI_API_URL}/chat/completions"),
    };
    let body = build_llm_request_body(provider, prompt, system_instruction, temperature);

    run_llm_with_retry(
        provider,
        || {
            execute_llm_request_cancellable(
                provider,
                client,
                &url,
                api_key,
                &body,
                cancellation_token,
            )
        },
        cancellation_token,
    )
}

#[cfg(test)]
mod tests {
    use super::{
        build_llm_request_body, classify_status, extract_gemini_text, extract_openai_text,
        map_provider_error, run_llm_with_retry, GeminiResponse, OpenAiResponse,
    };
    use crate::cancellation::CancellationToken;
    use crate::error::CoreError;
    use crate::retry::HttpResult;
    use crate::LlmProvider;
    use reqwest::StatusCode;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn build_llm_request_body_should_include_required_sections() {
        let body = build_llm_request_body(LlmProvider::GoogleAiStudio, "prompt", None, None);
        assert_eq!(body["contents"][0]["role"], "user");
        assert_eq!(body["contents"][0]["parts"][0]["text"], "prompt");
        assert_eq!(body["generationConfig"]["maxOutputTokens"], 4096);
    }

    #[test]
    fn build_llm_request_body_should_include_system_instruction_when_provided() {
        let body = build_llm_request_body(
            LlmProvider::GoogleAiStudio,
            "prompt",
            Some("be concise"),
            None,
        );
        assert_eq!(body["systemInstruction"]["parts"][0]["text"], "be concise");
    }

    #[test]
    fn build_llm_request_body_should_include_temperature_when_provided() {
        let body = build_llm_request_body(LlmProvider::GoogleAiStudio, "prompt", None, Some(0.3));
        let temperature = body["generationConfig"]["temperature"]
            .as_f64()
            .expect("temperature should be a number");
        assert!((temperature - 0.3).abs() < 0.000_001);
    }

    #[test]
    fn build_llm_request_body_should_support_openai_provider() {
        let body =
            build_llm_request_body(LlmProvider::Openai, "prompt", Some("be concise"), Some(0.7));

        assert_eq!(body["model"], "gpt-5.4-nano");
        assert_eq!(body["messages"][0]["role"], "system");
        assert_eq!(body["messages"][0]["content"], "be concise");
        assert_eq!(body["messages"][1]["role"], "user");
        assert_eq!(body["messages"][1]["content"], "prompt");
        let temperature = body["temperature"]
            .as_f64()
            .expect("temperature should be a number");
        assert!((temperature - 0.7).abs() < 0.000_001);
    }

    #[test]
    fn build_llm_request_body_should_skip_temperature_when_missing() {
        let body = build_llm_request_body(LlmProvider::GoogleAiStudio, "prompt", None, None);
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
    fn extract_openai_text_should_return_trimmed_value() {
        let payload: OpenAiResponse = serde_json::from_value(serde_json::json!({
            "choices": [{"message": {"content": "  result  "}}]
        }))
        .expect("valid payload");
        let result = extract_openai_text(payload);
        assert!(matches!(result, HttpResult::Success(text) if text == "result"));
    }

    #[test]
    fn extract_openai_text_should_fail_when_text_missing() {
        let payload: OpenAiResponse = serde_json::from_value(serde_json::json!({
            "choices": [{"message": {"content": null}}]
        }))
        .expect("valid payload");
        let result = extract_openai_text(payload);
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn classify_status_should_mark_retryable_statuses() {
        let result = classify_status(LlmProvider::GoogleAiStudio, StatusCode::INTERNAL_SERVER_ERROR);
        assert!(matches!(result, HttpResult::Retryable));
    }

    #[test]
    fn classify_status_should_mark_non_retryable_statuses() {
        let result = classify_status(LlmProvider::GoogleAiStudio, StatusCode::BAD_REQUEST);
        assert!(
            matches!(result, HttpResult::NonRetryable(msg) if msg == "Gemini API error: HTTP 400 Bad Request")
        );
    }

    #[test]
    fn classify_status_should_mark_openai_non_retryable_statuses() {
        let result = classify_status(LlmProvider::Openai, StatusCode::UNAUTHORIZED);
        assert!(
            matches!(result, HttpResult::NonRetryable(msg) if msg == "OpenAI API error: HTTP 401 Unauthorized")
        );
    }

    #[test]
    fn map_provider_error_should_map_empty_response_variant() {
        let error = map_provider_error(LlmProvider::GoogleAiStudio, "Empty response".to_string());
        assert!(matches!(error, CoreError::EmptyResponse));
    }

    #[test]
    fn map_provider_error_should_map_api_variant() {
        let error = map_provider_error(
            LlmProvider::GoogleAiStudio,
            "Gemini API error: HTTP 429 Too Many Requests".to_string(),
        );
        assert!(matches!(error, CoreError::Api(_)));
    }

    #[test]
    fn map_provider_error_should_map_http_variant() {
        let error = map_provider_error(LlmProvider::GoogleAiStudio, "network issue".to_string());
        assert!(matches!(error, CoreError::Http(_)));
    }

    #[test]
    fn map_provider_error_should_map_cancelled_variant() {
        let error = map_provider_error(
            LlmProvider::GoogleAiStudio,
            "Operation cancelled".to_string(),
        );
        assert!(matches!(error, CoreError::Cancelled));
    }

    #[test]
    fn run_llm_with_retry_should_retry_until_third_attempt_success() {
        let attempts = AtomicU32::new(0);

        let result = run_llm_with_retry(
            LlmProvider::GoogleAiStudio,
            || {
                let attempt = attempts.fetch_add(1, Ordering::SeqCst);
                if attempt < 2 {
                    HttpResult::Retryable
                } else {
                    HttpResult::Success("ok".to_string())
                }
            },
            None,
        );

        assert!(matches!(result, Ok(value) if value == "ok"));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn run_llm_with_retry_should_fail_after_retry_budget_exhausted() {
        let attempts = AtomicU32::new(0);

        let result = run_llm_with_retry(
            LlmProvider::GoogleAiStudio,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::Retryable
            },
            None,
        );

        assert!(
            matches!(result, Err(CoreError::Http(message)) if message == "Gemini API: retries exceeded")
        );
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn run_llm_with_retry_should_return_cancelled_before_first_attempt() {
        let token = CancellationToken::new();
        token.cancel();
        let attempts = AtomicU32::new(0);

        let result = run_llm_with_retry(
            LlmProvider::GoogleAiStudio,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::Success("ok".to_string())
            },
            Some(token.as_ref()),
        );

        assert!(matches!(result, Err(CoreError::Cancelled)));
        assert_eq!(attempts.load(Ordering::SeqCst), 0);
    }
}

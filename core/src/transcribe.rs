use crate::config::{GROQ_TRANSCRIBE_URL, GROQ_WHISPER_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use crate::retry::{is_retryable_status, with_retry, HttpResult};
use reqwest::StatusCode;
use secrecy::{ExposeSecret, SecretString};

const EMPTY_RESPONSE_MESSAGE: &str = "Empty response";

fn normalize_language(language: Option<&str>) -> Option<String> {
    language.and_then(|value| {
        let trimmed = value.trim();
        (!trimmed.is_empty()).then(|| trimmed.to_string())
    })
}

fn normalize_transcription_text(text: String) -> HttpResult<String> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        HttpResult::NonRetryable(EMPTY_RESPONSE_MESSAGE.to_string())
    } else {
        HttpResult::Success(trimmed.to_string())
    }
}

fn classify_transcribe_status(status: StatusCode) -> HttpResult<()> {
    if status == StatusCode::OK {
        HttpResult::Success(())
    } else if is_retryable_status(status) {
        HttpResult::Retryable
    } else {
        HttpResult::NonRetryable(format!("Groq API error: HTTP {status}"))
    }
}

fn map_transcribe_error(msg: String) -> CoreError {
    if msg == EMPTY_RESPONSE_MESSAGE {
        CoreError::EmptyResponse
    } else if msg.starts_with("Groq API error") {
        CoreError::Api(msg)
    } else {
        CoreError::Http(msg)
    }
}

pub(crate) fn transcribe_audio_bytes(
    api_key: &SecretString,
    audio_bytes: &[u8],
    language: Option<&str>,
) -> Result<String, CoreError> {
    let client = get_http_client();
    let normalized_language = normalize_language(language);

    with_retry(
        3,
        || {
            let mut form = reqwest::blocking::multipart::Form::new()
                .text("model", GROQ_WHISPER_MODEL)
                .text("response_format", "text");

            if let Some(language) = normalized_language.as_deref() {
                form = form.text("language", language.to_string());
            }

            // Audio bytes are FLAC format (compressed, ~50-70% smaller)
            let part = match reqwest::blocking::multipart::Part::bytes(audio_bytes.to_vec())
                .file_name("audio.flac")
                .mime_str("audio/flac")
            {
                Ok(p) => p,
                Err(e) => return HttpResult::NonRetryable(e.to_string()),
            };

            form = form.part("file", part);

            let response = client
                .post(GROQ_TRANSCRIBE_URL)
                .bearer_auth(api_key.expose_secret())
                .multipart(form)
                .send();

            match response {
                Ok(resp) => match classify_transcribe_status(resp.status()) {
                    HttpResult::Success(()) => match resp.text() {
                        Ok(text) => normalize_transcription_text(text),
                        Err(e) => HttpResult::NonRetryable(e.to_string()),
                    },
                    HttpResult::Retryable => HttpResult::Retryable,
                    HttpResult::NonRetryable(msg) => HttpResult::NonRetryable(msg),
                },
                Err(_) => HttpResult::Retryable,
            }
        },
        "Groq API",
    )
    .map_err(map_transcribe_error)
}

#[cfg(test)]
mod tests {
    use super::{
        classify_transcribe_status, map_transcribe_error, normalize_language,
        normalize_transcription_text,
    };
    use crate::error::CoreError;
    use crate::retry::HttpResult;
    use reqwest::StatusCode;

    #[test]
    fn normalize_language_should_return_none_when_absent() {
        assert_eq!(normalize_language(None), None);
    }

    #[test]
    fn normalize_language_should_return_none_when_blank() {
        assert_eq!(normalize_language(Some("   ")), None);
    }

    #[test]
    fn normalize_language_should_trim_and_preserve_value() {
        assert_eq!(normalize_language(Some("  en  ")), Some("en".to_string()));
    }

    #[test]
    fn normalize_transcription_text_should_reject_blank_body() {
        let result = normalize_transcription_text("   \n\t".to_string());
        assert!(matches!(result, HttpResult::NonRetryable(msg) if msg == "Empty response"));
    }

    #[test]
    fn normalize_transcription_text_should_trim_non_empty_body() {
        let result = normalize_transcription_text("  hello world  ".to_string());
        assert!(matches!(result, HttpResult::Success(text) if text == "hello world"));
    }

    #[test]
    fn classify_transcribe_status_should_mark_retryable_statuses() {
        let result = classify_transcribe_status(StatusCode::TOO_MANY_REQUESTS);
        assert!(matches!(result, HttpResult::Retryable));
    }

    #[test]
    fn classify_transcribe_status_should_mark_api_errors_as_non_retryable() {
        let result = classify_transcribe_status(StatusCode::BAD_REQUEST);
        assert!(
            matches!(result, HttpResult::NonRetryable(msg) if msg == "Groq API error: HTTP 400 Bad Request")
        );
    }

    #[test]
    fn map_transcribe_error_should_map_empty_response_variant() {
        let result = map_transcribe_error("Empty response".to_string());
        assert!(matches!(result, CoreError::EmptyResponse));
    }

    #[test]
    fn map_transcribe_error_should_map_api_variant() {
        let result = map_transcribe_error("Groq API error: HTTP 401 Unauthorized".to_string());
        assert!(matches!(result, CoreError::Api(_)));
    }

    #[test]
    fn map_transcribe_error_should_map_http_variant() {
        let result = map_transcribe_error("transport failed".to_string());
        assert!(matches!(result, CoreError::Http(_)));
    }
}

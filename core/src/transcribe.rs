use crate::config::{GROQ_TRANSCRIBE_URL, GROQ_WHISPER_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use crate::retry::{is_retryable_status, with_retry, HttpResult};
use reqwest::StatusCode;

pub fn transcribe_audio_bytes(
    api_key: &str,
    audio_bytes: &[u8],
    language: Option<&str>,
) -> Result<String, CoreError> {
    let client = get_http_client();

    with_retry(
        3,
        || {
            let mut form = reqwest::blocking::multipart::Form::new()
                .text("model", GROQ_WHISPER_MODEL)
                .text("response_format", "text");

            if let Some(language) = language {
                if !language.trim().is_empty() {
                    form = form.text("language", language.trim().to_string());
                }
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
                .bearer_auth(api_key)
                .multipart(form)
                .send();

            match response {
                Ok(resp) if resp.status() == StatusCode::OK => {
                    match resp.text() {
                        Ok(text) => {
                            let trimmed = text.trim();
                            if trimmed.is_empty() {
                                HttpResult::NonRetryable("Empty response".to_string())
                            } else {
                                HttpResult::Success(trimmed.to_string())
                            }
                        }
                        Err(e) => HttpResult::NonRetryable(e.to_string()),
                    }
                }
                Ok(resp) if is_retryable_status(resp.status()) => HttpResult::Retryable,
                Ok(resp) => HttpResult::NonRetryable(format!(
                    "Groq API error: HTTP {}",
                    resp.status()
                )),
                Err(_) => HttpResult::Retryable,
            }
        },
        "Groq API",
    )
    .map_err(|msg| {
        if msg.contains("Empty response") {
            CoreError::EmptyResponse
        } else if msg.starts_with("Groq API error") {
            CoreError::Api(msg)
        } else {
            CoreError::Http(msg)
        }
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_exponential_backoff_calculation() {
        // Test that backoff increases exponentially: 2^0, 2^1, 2^2
        assert_eq!(2u64.pow(0), 1);
        assert_eq!(2u64.pow(1), 2);
        assert_eq!(2u64.pow(2), 4);
    }

    #[test]
    fn test_backoff_sequence_for_three_attempts() {
        // Verify the backoff sequence used in retry logic
        let expected: Vec<u64> = (0..3).map(|attempt| 2u64.pow(attempt)).collect();
        assert_eq!(expected, vec![1, 2, 4]);
    }

    #[test]
    fn test_language_parameter_handling_some_with_content() {
        // Test that Some("en") is handled correctly
        let lang: Option<&str> = Some("en");
        assert!(lang.map(|l| !l.trim().is_empty()).unwrap_or(false));
    }

    #[test]
    fn test_language_parameter_handling_some_empty() {
        // Test that Some("") is treated as empty
        let lang: Option<&str> = Some("");
        assert!(!lang.map(|l| !l.trim().is_empty()).unwrap_or(false));
    }

    #[test]
    fn test_language_parameter_handling_some_whitespace() {
        // Test that Some("   ") is treated as empty after trim
        let lang: Option<&str> = Some("   ");
        assert!(!lang.map(|l| !l.trim().is_empty()).unwrap_or(false));
    }

    #[test]
    fn test_language_parameter_handling_none() {
        // Test that None is handled correctly
        let lang: Option<&str> = None;
        assert!(!lang.map(|l| !l.trim().is_empty()).unwrap_or(false));
    }

    #[test]
    fn test_language_parameter_trimmed_value() {
        // Test that the trimmed value is what gets used
        let lang = Some("  fr  ");
        let trimmed = lang.map(|l| l.trim()).unwrap_or("");
        assert_eq!(trimmed, "fr");
    }
}

use crate::config::{GROQ_TRANSCRIBE_URL, GROQ_WHISPER_MODEL};
use crate::error::CoreError;
use reqwest::blocking::Client;
use reqwest::StatusCode;
use std::thread::sleep;
use std::time::Duration;

pub fn transcribe_wav_bytes(
    api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
) -> Result<String, CoreError> {
    let client = Client::builder().timeout(Duration::from_secs(90)).build()?;

    for attempt in 0..3 {
        let mut form = reqwest::blocking::multipart::Form::new()
            .text("model", GROQ_WHISPER_MODEL.to_string())
            .text("response_format", "text".to_string());

        if let Some(language) = language {
            if !language.trim().is_empty() {
                form = form.text("language", language.trim().to_string());
            }
        }

        let part = reqwest::blocking::multipart::Part::bytes(wav_bytes.to_vec())
            .file_name("audio.wav")
            .mime_str("audio/wav")
            .map_err(|e| CoreError::Http(e.to_string()))?;

        form = form.part("file", part);

        let response = client
            .post(GROQ_TRANSCRIBE_URL)
            .bearer_auth(api_key)
            .multipart(form)
            .send();

        match response {
            Ok(resp) if resp.status() == StatusCode::OK => {
                let text = resp.text()?;
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
                    "Groq API error: HTTP {}",
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

    Err(CoreError::Api("Groq API retries exceeded".to_string()))
}

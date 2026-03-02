use crate::config::GEMINI_API_URL;
use crate::error::CoreError;
use reqwest::{blocking::Client as BlockingClient, Client as AsyncClient};
use std::sync::OnceLock;
use std::time::Duration;

const GROQ_MODELS_URL: &str = "https://api.groq.com/openai/v1/models";

/// Global HTTP client with connection pooling
/// Initialized lazily on first use
static HTTP_CLIENT: OnceLock<BlockingClient> = OnceLock::new();
static ASYNC_HTTP_CLIENT: OnceLock<AsyncClient> = OnceLock::new();

fn gemini_models_url() -> String {
    format!("{GEMINI_API_URL}/models")
}

fn warmup_error(target: &str, detail: impl std::fmt::Display) -> CoreError {
    CoreError::Http(format!("Failed to warmup {target} connection: {detail}"))
}

/// Get or initialize the global HTTP client
///
/// Configured with:
/// - pool_idle_timeout: 300s (keep connections alive for 5 minutes)
/// - pool_max_idle_per_host: 2 (allow 2 idle connections per host)
/// - timeout: 90s for request timeout
pub(crate) fn get_http_client() -> &'static BlockingClient {
    HTTP_CLIENT.get_or_init(|| {
        BlockingClient::builder()
            .timeout(Duration::from_secs(90))
            .pool_idle_timeout(Duration::from_secs(300))
            .pool_max_idle_per_host(2)
            .build()
            .expect("Failed to create HTTP client")
    })
}

/// Get or initialize the global async HTTP client.
pub(crate) fn get_async_http_client() -> &'static AsyncClient {
    ASYNC_HTTP_CLIENT.get_or_init(|| {
        AsyncClient::builder()
            .timeout(Duration::from_secs(90))
            .pool_idle_timeout(Duration::from_secs(300))
            .pool_max_idle_per_host(2)
            .build()
            .expect("Failed to create async HTTP client")
    })
}

/// Warm up the TLS connection to Groq API
///
/// This should be called at the start of recording to ensure
/// the TLS handshake is done before the actual transcription request.
/// Returns immediately on success, or error if connection fails.
///
/// # Timing Considerations
///
/// The HTTP client maintains a connection pool with a 300-second idle timeout.
/// If the time between warmup and the actual API call exceeds this limit,
/// the connection may be closed and a new TLS handshake will be required.
///
/// # Recommended Usage Pattern
///
/// ```ignore
/// // 1. User starts recording (presses button)
/// warmup_groq_connection()?; // Establish TLS connection
/// start_recording()?;
///
/// // 2. User stops recording
/// let audio = stop_recording()?;
///
/// // 3. Immediately transcribe (reuses warmed-up connection)
/// // If recording was < 5 minutes, the connection is still valid
/// transcribe_audio_bytes(api_key, audio.bytes, None)?;
/// ```
///
/// # When to Re-warm
///
/// Re-call this function if:
/// - More than ~4 minutes have passed since the last warmup
/// - A previous API call failed with a connection error
/// - The app has been backgrounded and resumed
pub(crate) fn warmup_groq_connection() -> Result<(), CoreError> {
    warmup_connection_with_label(GROQ_MODELS_URL, "Groq")
}

/// Warm up the TLS connection to Gemini API
///
/// Similar to Groq warmup, establishes TLS connection ahead of time.
///
/// # Timing Considerations
///
/// The HTTP client maintains a connection pool with a 300-second idle timeout.
/// If the time between warmup and the actual API call exceeds this limit,
/// the connection may be closed and a new TLS handshake will be required.
///
/// # Recommended Usage Pattern
///
/// ```ignore
/// // 1. Start recording
/// warmup_gemini_connection()?; // Pre-establish TLS connection
/// start_recording()?;
///
/// // 2. Recording in progress...
/// // (keep the connection alive with periodic activity or accept re-handshake)
///
/// // 3. Stop recording and polish immediately
/// let audio = stop_recording()?;
/// let text = transcribe_audio_bytes(api_key, audio.bytes, None)?;
///
/// // 4. Polish with Gemini (reuses connection if still valid)
/// polish_text(gemini_key, text, None)?;
/// ```
///
/// # When to Re-warm
///
/// Re-call this function if:
/// - More than ~4 minutes have passed since the last warmup
/// - A previous API call failed with a connection error
/// - You want to ensure minimal latency for a critical operation
pub(crate) fn warmup_gemini_connection() -> Result<(), CoreError> {
    warmup_connection_with_label(&gemini_models_url(), "Gemini")
}

/// Generic warmup for any URL
///
/// Used internally or for testing connection to custom endpoints.
#[expect(
    dead_code,
    reason = "Available for diagnostics and custom endpoint warmup in internal flows"
)]
pub(crate) fn warmup_connection(url: &str) -> Result<(), CoreError> {
    warmup_connection_with_label(url, "custom")
}

fn warmup_connection_with_label(url: &str, label: &str) -> Result<(), CoreError> {
    let client = get_http_client();

    let _ = client.get(url).send().map_err(|e| warmup_error(label, e))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{gemini_models_url, warmup_error, GROQ_MODELS_URL};
    use crate::config::GEMINI_API_URL;
    use crate::error::CoreError;

    #[test]
    fn gemini_models_url_should_append_models_suffix() {
        let url = gemini_models_url();
        assert_eq!(url, format!("{GEMINI_API_URL}/models"));
    }

    #[test]
    fn groq_models_url_should_match_expected_endpoint() {
        assert_eq!(GROQ_MODELS_URL, "https://api.groq.com/openai/v1/models");
    }

    #[test]
    fn warmup_error_should_return_http_variant_with_label() {
        let error = warmup_error("Gemini", "connection refused");
        assert!(
            matches!(error, CoreError::Http(message) if message == "Failed to warmup Gemini connection: connection refused")
        );
    }
}

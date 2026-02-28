use crate::config::GEMINI_API_URL;
use crate::error::CoreError;
use reqwest::blocking::Client;
use std::sync::OnceLock;
use std::time::Duration;

/// Global HTTP client with connection pooling
/// Initialized lazily on first use
static HTTP_CLIENT: OnceLock<Client> = OnceLock::new();

/// Get or initialize the global HTTP client
///
/// Configured with:
/// - pool_idle_timeout: 300s (keep connections alive for 5 minutes)
/// - pool_max_idle_per_host: 2 (allow 2 idle connections per host)
/// - timeout: 90s for request timeout
pub fn get_http_client() -> &'static Client {
    HTTP_CLIENT.get_or_init(|| {
        Client::builder()
            .timeout(Duration::from_secs(90))
            .pool_idle_timeout(Duration::from_secs(300))
            .pool_max_idle_per_host(2)
            .build()
            .expect("Failed to create HTTP client")
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
pub fn warmup_groq_connection() -> Result<(), CoreError> {
    let client = get_http_client();

    // Send a lightweight HEAD request to establish TLS connection
    // We use GET since HEAD might not be supported, but with minimal overhead
    let _ = client
        .get("https://api.groq.com/openai/v1/models")
        .send()
        .map_err(|e| CoreError::Http(format!("Failed to warmup Groq connection: {}", e)))?;

    Ok(())
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
pub fn warmup_gemini_connection() -> Result<(), CoreError> {
    let client = get_http_client();

    // Send a lightweight request to establish TLS connection
    let url = format!("{}/models", GEMINI_API_URL);
    let _ = client
        .get(&url)
        .send()
        .map_err(|e| CoreError::Http(format!("Failed to warmup Gemini connection: {}", e)))?;

    Ok(())
}

/// Generic warmup for any URL
///
/// Used internally or for testing connection to custom endpoints.
#[expect(dead_code, reason = "Used internally or for testing connection to custom endpoints")]
pub fn warmup_connection(url: &str) -> Result<(), CoreError> {
    let client = get_http_client();

    let _ = client
        .get(url)
        .send()
        .map_err(|e| CoreError::Http(format!("Failed to warmup connection to {}: {}", url, e)))?;

    Ok(())
}

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

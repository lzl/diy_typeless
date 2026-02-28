mod audio;
mod config;
mod error;
mod http_client;
mod llm_processor;
mod pipeline;
mod polish;
mod retry;
mod transcribe;

pub use audio::AudioData;
pub use error::CoreError;

#[uniffi::export]
pub fn start_recording() -> Result<(), CoreError> {
    audio::start_recording()
}

#[uniffi::export]
pub fn stop_recording() -> Result<AudioData, CoreError> {
    audio::stop_recording()
}

/// Stop recording and return WAV format (for CLI compatibility)
#[uniffi::export]
pub fn stop_recording_wav() -> Result<AudioData, CoreError> {
    audio::stop_recording_wav()
}

#[uniffi::export]
pub fn transcribe_audio_bytes(
    api_key: String,
    audio_bytes: Vec<u8>,
    language: Option<String>,
) -> Result<String, CoreError> {
    transcribe::transcribe_audio_bytes(&api_key, &audio_bytes, language.as_deref())
}

#[uniffi::export]
pub fn polish_text(
    api_key: String,
    raw_text: String,
    context: Option<String>,
) -> Result<String, CoreError> {
    polish::polish_text(&api_key, &raw_text, context.as_deref())
}

/// Warm up TLS connection to Groq API
///
/// Call this at the start of recording to eliminate TLS handshake latency.
/// See [`http_client::warmup_groq_connection`] for detailed timing considerations.
///
/// # Important
/// - The connection pool has a 300-second idle timeout
/// - For recordings longer than ~4 minutes, the connection may need re-warming
/// - This should be called immediately before or at the start of recording
#[uniffi::export]
pub fn warmup_groq_connection() -> Result<(), CoreError> {
    http_client::warmup_groq_connection()
}

/// Warm up TLS connection to Gemini API
///
/// Call this at the start of recording to eliminate TLS handshake latency.
/// See [`http_client::warmup_gemini_connection`] for detailed timing considerations.
///
/// # Important
/// - The connection pool has a 300-second idle timeout
/// - For long recording sessions, consider re-warming before polish
/// - This should be called immediately before or at the start of recording
#[uniffi::export]
pub fn warmup_gemini_connection() -> Result<(), CoreError> {
    http_client::warmup_gemini_connection()
}

/// Process text with LLM (Gemini API)
/// Generic function for processing text with custom prompts
#[uniffi::export]
pub fn process_text_with_llm(
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm(
        &api_key,
        &prompt,
        system_instruction.as_deref(),
        temperature,
    )
}

uniffi::setup_scaffolding!();

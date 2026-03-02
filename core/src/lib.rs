//! Core Rust library for audio capture, transcription, and text polishing.
//!
//! This crate exposes UniFFI-compatible functions used by the macOS app and CLI.

mod async_executor;
mod audio;
mod cancellation;
mod config;
mod error;
mod http_client;
mod llm_processor;
mod pipeline;
mod polish;
mod retry;
mod transcribe;

pub use audio::AudioData;
pub use cancellation::CoreCancellationToken;
pub use error::CoreError;

use secrecy::SecretString;
use std::sync::Arc;

#[uniffi::export]
/// Start microphone capture.
///
/// Returns an error if input audio device is unavailable or recording is already active.
pub fn start_recording() -> Result<(), CoreError> {
    audio::start_recording()
}

#[uniffi::export]
/// Stop microphone capture and return FLAC-encoded audio.
///
/// The returned payload is optimized for transcription upload.
pub fn stop_recording() -> Result<AudioData, CoreError> {
    audio::stop_recording()
}

#[uniffi::export]
/// Transcribe encoded audio bytes with Groq Whisper API.
pub fn transcribe_audio_bytes(
    api_key: String,
    audio_bytes: Vec<u8>,
    language: Option<String>,
) -> Result<String, CoreError> {
    let cancellation_token = CoreCancellationToken::new();
    transcribe::transcribe_audio_bytes(
        &SecretString::from(api_key),
        &audio_bytes,
        language.as_deref(),
        cancellation_token.as_ref(),
    )
}

#[uniffi::export]
/// Transcribe encoded audio bytes with Groq Whisper API, supporting cancellation.
pub fn transcribe_audio_bytes_cancellable(
    api_key: String,
    audio_bytes: Vec<u8>,
    language: Option<String>,
    cancellation_token: Arc<CoreCancellationToken>,
) -> Result<String, CoreError> {
    transcribe::transcribe_audio_bytes(
        &SecretString::from(api_key),
        &audio_bytes,
        language.as_deref(),
        cancellation_token.as_ref(),
    )
}

#[uniffi::export]
/// Polish raw transcript text with Gemini API.
pub fn polish_text(
    api_key: String,
    raw_text: String,
    context: Option<String>,
) -> Result<String, CoreError> {
    let cancellation_token = CoreCancellationToken::new();
    polish::polish_text(
        &SecretString::from(api_key),
        &raw_text,
        context.as_deref(),
        cancellation_token.as_ref(),
    )
}

#[uniffi::export]
/// Polish raw transcript text with Gemini API, supporting cancellation.
pub fn polish_text_cancellable(
    api_key: String,
    raw_text: String,
    context: Option<String>,
    cancellation_token: Arc<CoreCancellationToken>,
) -> Result<String, CoreError> {
    polish::polish_text(
        &SecretString::from(api_key),
        &raw_text,
        context.as_deref(),
        cancellation_token.as_ref(),
    )
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
/// Warm up TLS connection to Groq API.
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
/// Warm up TLS connection to Gemini API.
pub fn warmup_gemini_connection() -> Result<(), CoreError> {
    http_client::warmup_gemini_connection()
}

/// Process text with LLM (Gemini API)
/// Generic function for processing text with custom prompts
#[uniffi::export]
/// Process arbitrary text with Gemini API and optional system instruction.
pub fn process_text_with_llm(
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm(
        &SecretString::from(api_key),
        &prompt,
        system_instruction.as_deref(),
        temperature,
    )
}

uniffi::setup_scaffolding!();

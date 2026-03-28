//! Core Rust library for audio capture, transcription, and text polishing.
//!
//! This crate exposes UniFFI-compatible functions used by the macOS app and CLI.

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
pub use cancellation::CancellationToken;
pub use error::CoreError;

use secrecy::SecretString;
use std::sync::Arc;

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
/// Supported LLM providers for polish and generic text-processing flows.
pub enum LlmProvider {
    /// Google AI Studio Gemini API.
    GoogleAiStudio,
    /// OpenAI Chat Completions API.
    Openai,
}

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
    transcribe::transcribe_audio_bytes(
        &SecretString::from(api_key),
        &audio_bytes,
        language.as_deref(),
    )
}

#[uniffi::export]
/// Transcribe encoded audio bytes with Groq Whisper API.
///
/// Supports cooperative cancellation using a shared cancellation token.
pub fn transcribe_audio_bytes_cancellable(
    api_key: String,
    audio_bytes: Vec<u8>,
    language: Option<String>,
    cancellation_token: Arc<CancellationToken>,
) -> Result<String, CoreError> {
    transcribe::transcribe_audio_bytes_with_cancellation(
        &SecretString::from(api_key),
        &audio_bytes,
        language.as_deref(),
        Some(cancellation_token.as_ref()),
    )
}

#[uniffi::export]
/// Polish raw transcript text with the selected LLM provider.
pub fn polish_text(
    provider: LlmProvider,
    api_key: String,
    raw_text: String,
    context: Option<String>,
) -> Result<String, CoreError> {
    polish::polish_text(
        provider,
        &SecretString::from(api_key),
        &raw_text,
        context.as_deref(),
    )
}

#[uniffi::export]
/// Polish raw transcript text with the selected LLM provider.
///
/// Supports cooperative cancellation using a shared cancellation token.
pub fn polish_text_cancellable(
    provider: LlmProvider,
    api_key: String,
    raw_text: String,
    context: Option<String>,
    cancellation_token: Arc<CancellationToken>,
) -> Result<String, CoreError> {
    polish::polish_text_with_cancellation(
        provider,
        &SecretString::from(api_key),
        &raw_text,
        context.as_deref(),
        Some(cancellation_token.as_ref()),
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

/// Warm up TLS connection to the selected LLM provider.
///
/// Call this at the start of recording to eliminate TLS handshake latency.
///
/// # Important
/// - The connection pool has a 300-second idle timeout
/// - For long recording sessions, consider re-warming before polish
/// - This should be called immediately before or at the start of recording
#[uniffi::export]
/// Warm up TLS connection to the selected LLM provider.
pub fn warmup_llm_connection(provider: LlmProvider) -> Result<(), CoreError> {
    http_client::warmup_llm_connection(provider)
}

/// Process text with the selected LLM provider.
/// Generic function for processing text with custom prompts
#[uniffi::export]
/// Process arbitrary text with the selected LLM provider and optional system instruction.
pub fn process_text_with_llm(
    provider: LlmProvider,
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm(
        provider,
        &SecretString::from(api_key),
        &prompt,
        system_instruction.as_deref(),
        temperature,
    )
}

#[uniffi::export]
/// Process arbitrary text with the selected LLM provider and optional system instruction.
///
/// Supports cooperative cancellation using a shared cancellation token.
pub fn process_text_with_llm_cancellable(
    provider: LlmProvider,
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
    cancellation_token: Arc<CancellationToken>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm_with_cancellation(
        provider,
        &SecretString::from(api_key),
        &prompt,
        system_instruction.as_deref(),
        temperature,
        Some(cancellation_token.as_ref()),
    )
}

uniffi::setup_scaffolding!();

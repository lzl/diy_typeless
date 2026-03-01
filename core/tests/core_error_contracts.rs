//! Integration tests for stable public error/display contracts.
//!
//! These tests intentionally avoid network and audio device side effects.

use diy_typeless_core::{
    polish_text, process_text_with_llm, start_recording, stop_recording, transcribe_audio_bytes,
    warmup_gemini_connection, warmup_groq_connection, AudioData, CoreError,
};

type LlmFnSignature =
    fn(String, String, Option<String>, Option<f32>) -> Result<String, CoreError>;

#[test]
fn core_error_display_messages_are_stable_for_common_variants() {
    let already_active = CoreError::RecordingAlreadyActive;
    assert_eq!(already_active.to_string(), "Recording already active");

    let not_active = CoreError::RecordingNotActive;
    assert_eq!(not_active.to_string(), "Recording not active");

    let api = CoreError::Api("Gemini API error: HTTP 400 Bad Request".to_string());
    assert!(
        api.to_string()
            .contains("API error: Gemini API error: HTTP 400 Bad Request")
    );
}

#[test]
fn public_exports_have_expected_signatures() {
    let _start_fn: fn() -> Result<(), CoreError> = start_recording;
    let _stop_fn: fn() -> Result<AudioData, CoreError> = stop_recording;
    let _transcribe_fn: fn(String, Vec<u8>, Option<String>) -> Result<String, CoreError> =
        transcribe_audio_bytes;
    let _polish_fn: fn(String, String, Option<String>) -> Result<String, CoreError> = polish_text;
    let _warmup_groq_fn: fn() -> Result<(), CoreError> = warmup_groq_connection;
    let _warmup_gemini_fn: fn() -> Result<(), CoreError> = warmup_gemini_connection;
    let _llm_fn: LlmFnSignature = process_text_with_llm;
}

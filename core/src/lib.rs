mod audio;
mod config;
mod error;
mod pipeline;
mod polish;
mod qwen_asr_ffi;
mod streaming_asr;
mod transcribe;

use std::sync::Arc;

pub use audio::WavData;
pub use error::CoreError;
pub use streaming_asr::StreamingHandle;

#[uniffi::export]
pub fn start_recording() -> Result<(), CoreError> {
    audio::start_recording()
}

#[uniffi::export]
pub fn stop_recording() -> Result<WavData, CoreError> {
    audio::stop_recording()
}

#[uniffi::export]
pub fn transcribe_wav_bytes(
    api_key: String,
    wav_bytes: Vec<u8>,
    language: Option<String>,
) -> Result<String, CoreError> {
    transcribe::transcribe_wav_bytes(&api_key, &wav_bytes, language.as_deref())
}

#[uniffi::export]
pub fn polish_text(
    api_key: String,
    raw_text: String,
    context: Option<String>,
) -> Result<String, CoreError> {
    polish::polish_text(&api_key, &raw_text, context.as_deref())
}

// Local ASR related functions
#[uniffi::export]
pub fn init_local_asr(model_dir: String) -> Result<(), CoreError> {
    let path = std::path::Path::new(&model_dir);
    transcribe::init_local_asr(path)
}

#[uniffi::export]
pub fn is_local_asr_available() -> bool {
    transcribe::is_local_asr_available()
}

/// Transcribe with streaming output (real-time)
/// This function starts recording, streams audio to the ASR model,
/// and calls the callback with partial results as they become available.
/// Returns when recording is stopped.
#[uniffi::export]
pub fn transcribe_streaming(
    model_dir: String,
    language: Option<String>,
) -> Result<String, CoreError> {
    use crate::qwen_asr_ffi::QwenTranscriber;
    use crate::streaming_asr::start_streaming_transcription;

    let path = std::path::Path::new(&model_dir);
    let transcriber = Arc::new(QwenTranscriber::new(path)?);

    // Set up callback to print partial results
    let handle = start_streaming_transcription(
        transcriber,
        language.as_deref(),
        |token| {
            eprint!("{}", token);
            std::io::Write::flush(&mut std::io::stderr()).ok();
        },
    )?;

    // Wait for user to stop (in a real app this would be triggered by UI)
    // For now, we'll stop after a fixed duration or when buffer is large enough
    std::thread::sleep(std::time::Duration::from_secs(5));

    handle.stop()
}

uniffi::setup_scaffolding!();

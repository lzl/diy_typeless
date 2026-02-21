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

/// Global storage for active streaming sessions
/// This allows Swift to reference sessions by ID and poll for results
static ACTIVE_STREAMING_SESSIONS: std::sync::Mutex<Vec<(u64, Arc<crate::streaming_asr::StreamingHandle>)>> =
    std::sync::Mutex::new(Vec::new());

static NEXT_SESSION_ID: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

/// Start a streaming transcription session
/// Returns a session ID that can be used to poll for results and stop the session
/// This is only used for local ASR (streaming mode)
#[uniffi::export]
pub fn start_streaming_session(
    model_dir: String,
    language: Option<String>,
) -> Result<u64, CoreError> {
    use crate::qwen_asr_ffi::QwenTranscriber;
    use crate::streaming_asr::start_streaming_transcription;

    let path = std::path::Path::new(&model_dir);
    let transcriber = Arc::new(QwenTranscriber::new(path)?);

    let handle = start_streaming_transcription(
        transcriber,
        language.as_deref(),
        |_token| {
            // Token callback is handled internally, Swift polls for results
        },
    )?;

    let session_id = NEXT_SESSION_ID.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    let mut sessions = ACTIVE_STREAMING_SESSIONS.lock().unwrap();
    sessions.push((session_id, Arc::new(handle)));

    Ok(session_id)
}

/// Get the current partial transcription for a streaming session
/// Returns the accumulated text so far, or empty string if session not found
#[uniffi::export]
pub fn get_streaming_text(session_id: u64) -> String {
    let sessions = ACTIVE_STREAMING_SESSIONS.lock().unwrap();
    if let Some((_, handle)) = sessions.iter().find(|(id, _)| *id == session_id) {
        handle.current_text()
    } else {
        String::new()
    }
}

/// Check if a streaming session is still running
#[uniffi::export]
pub fn is_streaming_session_active(session_id: u64) -> bool {
    let sessions = ACTIVE_STREAMING_SESSIONS.lock().unwrap();
    if let Some((_, handle)) = sessions.iter().find(|(id, _)| *id == session_id) {
        handle.is_running()
    } else {
        false
    }
}

/// Stop a streaming transcription session and return the final text
/// This removes the session from the active sessions list
#[uniffi::export]
pub fn stop_streaming_session(session_id: u64) -> Result<String, CoreError> {
    let handle = {
        let mut sessions = ACTIVE_STREAMING_SESSIONS.lock().unwrap();
        let index = sessions.iter().position(|(id, _)| *id == session_id);
        if let Some(idx) = index {
            let (_, handle) = sessions.remove(idx);
            // We need to unwrap the Arc to call stop(), but Arc::into_inner requires nightly
            // Instead, we'll use a workaround with try_unwrap
            match Arc::try_unwrap(handle) {
                Ok(h) => h,
                Err(arc) => {
                    // If we can't unwrap, we can't stop - return error
                    // Put it back in the list
                    sessions.push((session_id, arc));
                    return Err(CoreError::Transcription(
                        "Streaming session is still in use".to_string()
                    ));
                }
            }
        } else {
            return Err(CoreError::Transcription(
                "Streaming session not found".to_string()
            ));
        }
    };

    handle.stop()
}

uniffi::setup_scaffolding!();

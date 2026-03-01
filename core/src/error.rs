use thiserror::Error;

#[derive(Debug, Error, uniffi::Error)]
/// Unified error type returned by core operations.
pub enum CoreError {
    /// No default input audio device is available.
    #[error("Audio device not available")]
    AudioDeviceUnavailable,
    /// Recording was started while another capture session is active.
    #[error("Recording already active")]
    RecordingAlreadyActive,
    /// Recording was stopped without an active capture session.
    #[error("Recording not active")]
    RecordingNotActive,
    /// Audio capture failed.
    #[error("Audio capture failed: {0}")]
    AudioCapture(String),
    /// Audio processing failed.
    #[error("Audio processing failed: {0}")]
    AudioProcessing(String),
    /// HTTP transport failed.
    #[error("HTTP error: {0}")]
    Http(String),
    /// Remote API returned a non-success response.
    #[error("API error: {0}")]
    Api(String),
    /// Serialization or deserialization failed.
    #[error("Serialization error: {0}")]
    Serialization(String),
    /// API returned no usable content.
    #[error("Unexpected empty response")]
    EmptyResponse,
    /// Transcription operation failed.
    #[error("Transcription failed: {0}")]
    Transcription(String),
    /// Configuration is invalid or missing.
    #[error("Configuration error: {0}")]
    Config(String),
}

impl From<reqwest::Error> for CoreError {
    fn from(err: reqwest::Error) -> Self {
        CoreError::Http(err.to_string())
    }
}

impl From<serde_json::Error> for CoreError {
    fn from(err: serde_json::Error) -> Self {
        CoreError::Serialization(err.to_string())
    }
}

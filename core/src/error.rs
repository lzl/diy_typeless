use thiserror::Error;

#[derive(Debug, Error, uniffi::Error)]
/// Unified error type returned by core operations.
pub enum CoreError {
    /// Operation was cancelled by caller.
    #[error("Operation cancelled")]
    Cancelled,
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

#[cfg(test)]
mod tests {
    use super::CoreError;

    #[test]
    fn core_error_display_messages_should_match_contract() {
        assert_eq!(CoreError::Cancelled.to_string(), "Operation cancelled");
        assert_eq!(
            CoreError::AudioDeviceUnavailable.to_string(),
            "Audio device not available"
        );
        assert_eq!(
            CoreError::RecordingAlreadyActive.to_string(),
            "Recording already active"
        );
        assert_eq!(
            CoreError::RecordingNotActive.to_string(),
            "Recording not active"
        );
        assert_eq!(
            CoreError::AudioCapture("x".to_string()).to_string(),
            "Audio capture failed: x"
        );
        assert_eq!(
            CoreError::AudioProcessing("x".to_string()).to_string(),
            "Audio processing failed: x"
        );
        assert_eq!(
            CoreError::Http("x".to_string()).to_string(),
            "HTTP error: x"
        );
        assert_eq!(CoreError::Api("x".to_string()).to_string(), "API error: x");
        assert_eq!(
            CoreError::Serialization("x".to_string()).to_string(),
            "Serialization error: x"
        );
        assert_eq!(
            CoreError::EmptyResponse.to_string(),
            "Unexpected empty response"
        );
        assert_eq!(
            CoreError::Transcription("x".to_string()).to_string(),
            "Transcription failed: x"
        );
        assert_eq!(
            CoreError::Config("x".to_string()).to_string(),
            "Configuration error: x"
        );
    }

    #[test]
    fn from_serde_json_error_should_map_to_serialization_variant() {
        let parse_error = serde_json::from_str::<serde_json::Value>("{bad json}")
            .expect_err("invalid json should fail");
        let mapped: CoreError = parse_error.into();
        assert!(matches!(mapped, CoreError::Serialization(_)));
    }

    #[test]
    fn from_reqwest_error_should_map_to_http_variant() {
        let error = reqwest::blocking::Client::new()
            .get("http://[::1")
            .send()
            .expect_err("invalid URL should fail");
        let mapped: CoreError = error.into();
        assert!(matches!(mapped, CoreError::Http(_)));
    }
}

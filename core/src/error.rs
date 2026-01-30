 use thiserror::Error;
 
 #[derive(Debug, Error, uniffi::Error)]
 pub enum CoreError {
     #[error("Audio device not available")]
     AudioDeviceUnavailable,
     #[error("Recording already active")]
     RecordingAlreadyActive,
     #[error("Recording not active")]
     RecordingNotActive,
     #[error("Audio capture failed: {0}")]
     AudioCapture(String),
     #[error("Audio processing failed: {0}")]
     AudioProcessing(String),
     #[error("HTTP error: {0}")]
     Http(String),
     #[error("API error: {0}")]
     Api(String),
     #[error("Serialization error: {0}")]
     Serialization(String),
     #[error("Unexpected empty response")]
     EmptyResponse,
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
 

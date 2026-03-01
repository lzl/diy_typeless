//! Integration tests for stable public error/display contracts.
//!
//! These tests intentionally avoid network and audio device side effects.

use diy_typeless_core::{
    stop_recording, CoreError,
};

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
fn stop_recording_should_fail_with_not_active_when_no_session_started() {
    let result = stop_recording();
    assert!(matches!(result, Err(CoreError::RecordingNotActive)));
}

#[test]
fn serde_json_errors_should_map_to_serialization_core_error() {
    let parse_result = serde_json::from_str::<serde_json::Value>("{invalid json}");
    let parse_error = parse_result.expect_err("Expected invalid JSON to fail parsing");
    let core_error: CoreError = parse_error.into();
    assert!(matches!(core_error, CoreError::Serialization(_)));
}

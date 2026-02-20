mod audio;
mod config;
mod error;
mod pipeline;
mod polish;
mod qwen_asr_ffi;
mod transcribe;

pub use audio::WavData;
pub use error::CoreError;

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

uniffi::setup_scaffolding!();

 mod audio;
 mod config;
 mod error;
 mod pipeline;
 mod polish;
 mod transcribe;
 
 pub use audio::WavData;
 pub use error::CoreError;
 pub use pipeline::PipelineResult;
 
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
 pub fn polish_text(api_key: String, raw_text: String) -> Result<String, CoreError> {
     polish::polish_text(&api_key, &raw_text)
 }
 
 #[uniffi::export]
 pub fn process_wav_bytes(
     groq_api_key: String,
     gemini_api_key: String,
     wav_bytes: Vec<u8>,
     language: Option<String>,
 ) -> Result<PipelineResult, CoreError> {
     pipeline::process_wav_bytes(
         &groq_api_key,
         &gemini_api_key,
         &wav_bytes,
         language.as_deref(),
     )
 }
 
 uniffi::setup_scaffolding!();
 

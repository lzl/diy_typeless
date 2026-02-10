use crate::error::CoreError;
use crate::polish::polish_text;
use crate::transcribe::transcribe_wav_bytes;

#[derive(Debug, uniffi::Record)]
pub struct PipelineResult {
    pub raw_text: String,
    pub polished_text: String,
}

pub fn process_wav_bytes(
    groq_api_key: &str,
    gemini_api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
    context: Option<&str>,
) -> Result<PipelineResult, CoreError> {
    let raw = transcribe_wav_bytes(groq_api_key, wav_bytes, language)?;
    let polished = polish_text(gemini_api_key, &raw, context)?;
    Ok(PipelineResult {
        raw_text: raw,
        polished_text: polished,
    })
}

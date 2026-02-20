use crate::error::CoreError;
use crate::transcribe::{transcribe_wav_bytes, transcribe_wav_bytes_local};

#[derive(Debug, uniffi::Record)]
pub struct PipelineResult {
    pub raw_text: String,
    pub polished_text: String,
}

// ASR provider enum
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AsrProvider {
    Groq,
    Local,
}

pub fn process_wav_bytes(
    groq_api_key: &str,
    _gemini_api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
    _context: Option<&str>,
) -> Result<PipelineResult, CoreError> {
    // If groq_api_key is empty and local ASR is available, use local ASR
    let raw = if groq_api_key.is_empty() && crate::transcribe::is_local_asr_available() {
        transcribe_wav_bytes_local(wav_bytes, language)?
    } else {
        transcribe_wav_bytes(groq_api_key, wav_bytes, language)?
    };
    // Return raw text only; polishing will be done on Swift side for better UX
    Ok(PipelineResult {
        raw_text: raw.clone(),
        polished_text: raw,
    })
}

// Generic transcription interface
pub fn process_wav_bytes_with_provider(
    provider: AsrProvider,
    groq_api_key: Option<&str>,
    _gemini_api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
    _context: Option<&str>,
) -> Result<PipelineResult, CoreError> {
    let raw = match provider {
        AsrProvider::Groq => {
            let api_key = groq_api_key.ok_or_else(|| {
                CoreError::Config("Groq API key required for remote ASR".to_string())
            })?;
            transcribe_wav_bytes(api_key, wav_bytes, language)?
        }
        AsrProvider::Local => {
            transcribe_wav_bytes_local(wav_bytes, language)?
        }
    };

    // Return raw text only; polishing will be done on Swift side for better UX
    Ok(PipelineResult {
        raw_text: raw.clone(),
        polished_text: raw,
    })
}

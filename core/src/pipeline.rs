use crate::error::CoreError;
use crate::polish::polish_text;
use crate::transcribe::{transcribe_wav_bytes, transcribe_wav_bytes_local};

#[derive(Debug, uniffi::Record)]
pub struct PipelineResult {
    pub raw_text: String,
    pub polished_text: String,
}

// ASR 提供商枚举
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AsrProvider {
    Groq,
    Local,
}

pub fn process_wav_bytes(
    groq_api_key: &str,
    gemini_api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
    context: Option<&str>,
) -> Result<PipelineResult, CoreError> {
    // 如果 groq_api_key 为空且本地 ASR 可用，使用本地 ASR
    let raw = if groq_api_key.is_empty() && crate::transcribe::is_local_asr_available() {
        transcribe_wav_bytes_local(wav_bytes, language)?
    } else {
        transcribe_wav_bytes(groq_api_key, wav_bytes, language)?
    };
    let polished = polish_text(gemini_api_key, &raw, context)?;
    Ok(PipelineResult {
        raw_text: raw,
        polished_text: polished,
    })
}

// 通用转录接口
pub fn process_wav_bytes_with_provider(
    provider: AsrProvider,
    groq_api_key: Option<&str>,
    gemini_api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
    context: Option<&str>,
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

    let polished = polish_text(gemini_api_key, &raw, context)?;
    Ok(PipelineResult {
        raw_text: raw,
        polished_text: polished,
    })
}

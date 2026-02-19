use crate::config::{GROQ_TRANSCRIBE_URL, GROQ_WHISPER_MODEL};
use crate::error::CoreError;
use crate::qwen_asr_ffi::QwenTranscriber;
use reqwest::blocking::Client;
use reqwest::StatusCode;
use std::path::Path;
use std::sync::OnceLock;
use std::thread::sleep;
use std::time::Duration;

// 全局本地转录器（懒加载）
static LOCAL_TRANSCRIBER: OnceLock<QwenTranscriber> = OnceLock::new();

/// 初始化本地 ASR 模型
pub fn init_local_asr(model_dir: &Path) -> Result<(), CoreError> {
    let transcriber = QwenTranscriber::new(model_dir)?;
    LOCAL_TRANSCRIBER
        .set(transcriber)
        .map_err(|_| CoreError::Config("Local ASR already initialized".to_string()))?;
    Ok(())
}

/// 本地 ASR 是否已初始化
pub fn is_local_asr_available() -> bool {
    LOCAL_TRANSCRIBER.get().is_some()
}

/// 使用本地 Qwen3-ASR 转录
pub fn transcribe_wav_bytes_local(
    wav_bytes: &[u8],
    language: Option<&str>,
) -> Result<String, CoreError> {
    let transcriber = LOCAL_TRANSCRIBER
        .get()
        .ok_or_else(|| CoreError::Config("Local ASR not initialized".to_string()))?;

    // 解析 WAV 获取样本
    let samples = decode_wav_to_f32(wav_bytes)?;

    let text = transcriber.transcribe_samples(&samples, 16000, language)?;
    Ok(text)
}

/// 解码 WAV 为 f32 样本（16kHz mono）
fn decode_wav_to_f32(wav_bytes: &[u8]) -> Result<Vec<f32>, CoreError> {
    use hound::WavReader;
    use std::io::Cursor;

    let reader = WavReader::new(Cursor::new(wav_bytes))
        .map_err(|e| CoreError::AudioProcessing(format!("Invalid WAV: {}", e)))?;

    let spec = reader.spec();
    if spec.sample_rate != 16000 {
        return Err(CoreError::AudioProcessing(format!(
            "Expected 16kHz, got {}Hz",
            spec.sample_rate
        )));
    }

    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Int => reader
            .into_samples::<i16>()
            .map(|s| s.map(|v| v as f32 / 32768.0))
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| CoreError::AudioProcessing(format!("WAV decode error: {}", e)))?,
        hound::SampleFormat::Float => reader
            .into_samples::<f32>()
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| CoreError::AudioProcessing(format!("WAV decode error: {}", e)))?,
    };

    // 如果是多声道，转换为单声道
    let channels = spec.channels as usize;
    if channels > 1 {
        let mono_samples: Vec<f32> = samples
            .chunks(channels)
            .map(|chunk| chunk.iter().sum::<f32>() / channels as f32)
            .collect();
        Ok(mono_samples)
    } else {
        Ok(samples)
    }
}

pub fn transcribe_wav_bytes(
    api_key: &str,
    wav_bytes: &[u8],
    language: Option<&str>,
) -> Result<String, CoreError> {
    let client = Client::builder().timeout(Duration::from_secs(90)).build()?;

    for attempt in 0..3 {
        let mut form = reqwest::blocking::multipart::Form::new()
            .text("model", GROQ_WHISPER_MODEL.to_string())
            .text("response_format", "text".to_string());

        if let Some(language) = language {
            if !language.trim().is_empty() {
                form = form.text("language", language.trim().to_string());
            }
        }

        let part = reqwest::blocking::multipart::Part::bytes(wav_bytes.to_vec())
            .file_name("audio.wav")
            .mime_str("audio/wav")
            .map_err(|e| CoreError::Http(e.to_string()))?;

        form = form.part("file", part);

        let response = client
            .post(GROQ_TRANSCRIBE_URL)
            .bearer_auth(api_key)
            .multipart(form)
            .send();

        match response {
            Ok(resp) if resp.status() == StatusCode::OK => {
                let text = resp.text()?;
                let trimmed = text.trim();
                if trimmed.is_empty() {
                    return Err(CoreError::EmptyResponse);
                }
                return Ok(trimmed.to_string());
            }
            Ok(resp)
                if resp.status() == StatusCode::TOO_MANY_REQUESTS
                    || resp.status().is_server_error() =>
            {
                let backoff = 2u64.pow(attempt);
                sleep(Duration::from_secs(backoff));
                continue;
            }
            Ok(resp) => {
                return Err(CoreError::Api(format!(
                    "Groq API error: HTTP {}",
                    resp.status()
                )));
            }
            Err(err) => {
                if attempt < 2 {
                    let backoff = 2u64.pow(attempt);
                    sleep(Duration::from_secs(backoff));
                    continue;
                }
                return Err(CoreError::Http(err.to_string()));
            }
        }
    }

    Err(CoreError::Api("Groq API retries exceeded".to_string()))
}

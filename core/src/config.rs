pub(crate) const WHISPER_SAMPLE_RATE: u32 = 16_000;
pub(crate) const WHISPER_CHANNELS: u16 = 1;

pub(crate) const GROQ_TRANSCRIBE_URL: &str = "https://api.groq.com/openai/v1/audio/transcriptions";
pub(crate) const GROQ_WHISPER_MODEL: &str = "whisper-large-v3-turbo";

pub(crate) const GEMINI_MODEL: &str = "gemini-3.1-flash-lite-preview";
pub(crate) const GEMINI_API_URL: &str = "https://generativelanguage.googleapis.com/v1beta/models";
pub(crate) const OPENAI_MODEL: &str = "gpt-5.4-nano";
pub(crate) const OPENAI_API_URL: &str = "https://api.openai.com/v1";

pub(crate) const HIGHPASS_FREQ_HZ: f32 = 80.0;
pub(crate) const TARGET_RMS_DB: f32 = -18.0;

#[cfg(test)]
mod tests {
    use super::{
        GEMINI_API_URL, GROQ_TRANSCRIBE_URL, HIGHPASS_FREQ_HZ, OPENAI_API_URL, TARGET_RMS_DB,
        WHISPER_CHANNELS, WHISPER_SAMPLE_RATE,
    };
    use std::hint::black_box;

    #[test]
    fn whisper_audio_constants_should_be_valid() {
        assert!(black_box(WHISPER_SAMPLE_RATE) > 0);
        assert!(black_box(WHISPER_CHANNELS) > 0);
    }

    #[test]
    fn api_urls_should_use_https() {
        assert!(GROQ_TRANSCRIBE_URL.starts_with("https://"));
        assert!(GEMINI_API_URL.starts_with("https://"));
        assert!(OPENAI_API_URL.starts_with("https://"));
    }

    #[test]
    fn audio_tuning_constants_should_be_in_sane_range() {
        assert!(black_box(HIGHPASS_FREQ_HZ) > 0.0);
        assert!(black_box(TARGET_RMS_DB) < 0.0);
    }
}

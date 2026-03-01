pub(crate) const WHISPER_SAMPLE_RATE: u32 = 16_000;
pub(crate) const WHISPER_CHANNELS: u16 = 1;

pub(crate) const GROQ_TRANSCRIBE_URL: &str = "https://api.groq.com/openai/v1/audio/transcriptions";
pub(crate) const GROQ_WHISPER_MODEL: &str = "whisper-large-v3-turbo";

pub(crate) const GEMINI_MODEL: &str = "gemini-2.5-flash-lite-preview-09-2025";
pub(crate) const GEMINI_API_URL: &str = "https://generativelanguage.googleapis.com/v1beta/models";

pub(crate) const HIGHPASS_FREQ_HZ: f32 = 80.0;
pub(crate) const TARGET_RMS_DB: f32 = -18.0;

 pub const WHISPER_SAMPLE_RATE: u32 = 16_000;
 pub const WHISPER_CHANNELS: u16 = 1;
 
 pub const GROQ_TRANSCRIBE_URL: &str = "https://api.groq.com/openai/v1/audio/transcriptions";
 pub const GROQ_WHISPER_MODEL: &str = "whisper-large-v3-turbo";
 
 pub const GEMINI_MODEL: &str = "gemini-2.5-flash-lite-preview-09-2025";
 pub const GEMINI_API_URL: &str = "https://generativelanguage.googleapis.com/v1beta/models";
 
 pub const HIGHPASS_FREQ_HZ: f32 = 80.0;
 pub const TARGET_RMS_DB: f32 = -18.0;
 pub const MAX_GAIN: f32 = 20.0;
 pub const SOFT_LIMIT_THRESHOLD: f32 = 0.7;
 pub const PEAK_NORMALIZE_TARGET: f32 = 0.95;
 

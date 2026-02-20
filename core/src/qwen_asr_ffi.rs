/*! Rust FFI bindings for Qwen3-ASR C library
 *
 * Based on antirez/qwen-asr: https://github.com/antirez/qwen-asr
 */

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int, c_void};
use std::path::Path;

use crate::error::CoreError;

// C type definitions
pub type QwenContext = c_void;

extern "C" {
    // Load/free model
    fn qwen_load(model_dir: *const c_char) -> *mut QwenContext;
    fn qwen_free(ctx: *mut QwenContext);

    // Set forced language
    fn qwen_set_force_language(ctx: *mut QwenContext, language: *const c_char) -> c_int;

    // Transcription interface
    fn qwen_transcribe_audio(
        ctx: *mut QwenContext,
        samples: *const c_float,
        n_samples: c_int,
    ) -> *mut c_char;
}

/// Qwen3-ASR transcriber
pub struct QwenTranscriber {
    ctx: *mut QwenContext,
}

unsafe impl Send for QwenTranscriber {}
unsafe impl Sync for QwenTranscriber {}

impl QwenTranscriber {
    /// Load model
    pub fn new(model_dir: &Path) -> Result<Self, CoreError> {
        let model_dir_c = CString::new(model_dir.to_str().ok_or_else(|| {
            CoreError::Config("Invalid model path".to_string())
        })?).map_err(|e| CoreError::Config(e.to_string()))?;

        let ctx = unsafe { qwen_load(model_dir_c.as_ptr()) };

        if ctx.is_null() {
            return Err(CoreError::Config("Failed to load Qwen3-ASR model".to_string()));
        }

        Ok(Self { ctx })
    }

    /// Set forced language
    pub fn set_language(&self, language: Option<&str>) -> Result<(), CoreError> {
        if let Some(lang) = language {
            let lang_c = CString::new(lang).map_err(|e| CoreError::Config(e.to_string()))?;
            let result = unsafe { qwen_set_force_language(self.ctx, lang_c.as_ptr()) };
            if result != 0 {
                return Err(CoreError::Config(format!(
                    "Failed to set language: {}",
                    lang
                )));
            }
        }
        Ok(())
    }

    /// Transcribe raw audio samples (16kHz mono f32)
    pub fn transcribe_samples(
        &self,
        samples: &[f32],
        _sample_rate: u32,
        language: Option<&str>,
    ) -> Result<String, CoreError> {
        // Set language first (if provided)
        self.set_language(language)?;

        let result_ptr = unsafe {
            qwen_transcribe_audio(
                self.ctx,
                samples.as_ptr() as *const c_float,
                samples.len() as c_int,
            )
        };

        if result_ptr.is_null() {
            return Err(CoreError::Transcription("Transcription failed".to_string()));
        }

        unsafe {
            let text = CStr::from_ptr(result_ptr)
                .to_string_lossy()
                .into_owned();

            // Free C-allocated string
            libc::free(result_ptr as *mut c_void);

            Ok(text)
        }
    }
}

impl Drop for QwenTranscriber {
    fn drop(&mut self) {
        unsafe {
            qwen_free(self.ctx);
        }
    }
}

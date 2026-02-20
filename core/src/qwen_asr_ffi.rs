/*! Rust FFI bindings for Qwen3-ASR C library
 *
 * Based on antirez/qwen-asr: https://github.com/antirez/qwen-asr
 */

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int, c_void};
use std::path::Path;
use std::sync::Mutex;

use crate::error::CoreError;

// C type definitions
pub type QwenContext = c_void;

/// Token callback type for streaming transcription
pub type QwenTokenCallback = unsafe extern "C" fn(token: *const c_char, userdata: *mut c_void);

/// Live audio structure for streaming transcription
/// Mirrors qwen_live_audio_t from C library
#[repr(C)]
pub struct QwenLiveAudio {
    pub samples: *mut c_float,
    pub sample_offset: i64,
    pub n_samples: i64,
    pub capacity: i64,
    pub eof: c_int,
    pub mutex: *mut c_void,  // pthread_mutex_t*
    pub cond: *mut c_void,   // pthread_cond_t*
    pub thread: u64,         // pthread_t
}

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

    // Streaming transcription interface
    fn qwen_set_token_callback(ctx: *mut QwenContext, cb: Option<QwenTokenCallback>, userdata: *mut c_void);
    fn qwen_transcribe_stream(ctx: *mut QwenContext, samples: *const c_float, n_samples: c_int) -> *mut c_char;
    fn qwen_transcribe_stream_live(ctx: *mut QwenContext, live: *mut QwenLiveAudio) -> *mut c_char;
}

/// Qwen3-ASR transcriber
///
/// Thread-safe wrapper around the C library context.
/// The Mutex ensures only one thread can access the C context at a time.
pub struct QwenTranscriber {
    ctx: Mutex<*mut QwenContext>,
}

unsafe impl Send for QwenTranscriber {}
unsafe impl Sync for QwenTranscriber {}

unsafe impl Send for QwenLiveAudio {}
unsafe impl Sync for QwenLiveAudio {}

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

        Ok(Self { ctx: Mutex::new(ctx) })
    }

    /// Set forced language
    pub fn set_language(&self, language: Option<&str>) -> Result<(), CoreError> {
        if let Some(lang) = language {
            let lang_c = CString::new(lang).map_err(|e| CoreError::Config(e.to_string()))?;
            let ctx = self.ctx.lock().unwrap();
            let result = unsafe { qwen_set_force_language(*ctx, lang_c.as_ptr()) };
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

        let ctx = self.ctx.lock().unwrap();
        let result_ptr = unsafe {
            qwen_transcribe_audio(
                *ctx,
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

impl QwenTranscriber {
    /// Get raw context pointer for streaming operations
    /// SAFETY: Caller must ensure the transcriber outlives the usage of the pointer
    pub fn raw_ctx(&self) -> *mut QwenContext {
        // We need to return the pointer without locking forever
        // Since the ctx pointer itself doesn't change after creation,
        // we can safely return a copy of it
        let ctx = self.ctx.lock().unwrap();
        *ctx
    }

    /// Set token callback for streaming transcription
    pub fn set_token_callback<F>(&self, callback: F)
    where
        F: FnMut(String) + Send + 'static,
    {
        let ctx = self.ctx.lock().unwrap();

        // Box the callback and convert to raw pointer
        let boxed = Box::new(callback);
        let userdata = Box::into_raw(boxed) as *mut c_void;

        unsafe {
            qwen_set_token_callback(*ctx, Some(token_callback_trampoline::<F>), userdata);
        }
    }

    /// Clear token callback
    pub fn clear_token_callback(&self) {
        let ctx = self.ctx.lock().unwrap();
        unsafe {
            qwen_set_token_callback(*ctx, None, std::ptr::null_mut());
        }
    }

    /// Transcribe with streaming (for pre-recorded audio with streaming output)
    pub fn transcribe_stream(
        &self,
        samples: &[f32],
        _sample_rate: u32,
        language: Option<&str>,
    ) -> Result<String, CoreError> {
        self.set_language(language)?;

        let ctx = self.ctx.lock().unwrap();
        let result_ptr = unsafe {
            qwen_transcribe_stream(
                *ctx,
                samples.as_ptr() as *const c_float,
                samples.len() as c_int,
            )
        };

        if result_ptr.is_null() {
            return Err(CoreError::Transcription("Streaming transcription failed".to_string()));
        }

        unsafe {
            let text = CStr::from_ptr(result_ptr)
                .to_string_lossy()
                .into_owned();
            libc::free(result_ptr as *mut c_void);
            Ok(text)
        }
    }

    /// Live streaming transcription
    /// Blocks until streaming is complete (live.eof is set)
    pub fn transcribe_stream_live(
        &self,
        live: *mut QwenLiveAudio,
        language: Option<&str>,
    ) -> Result<String, CoreError> {
        self.set_language(language)?;

        let ctx = self.ctx.lock().unwrap();
        let result_ptr = unsafe {
            qwen_transcribe_stream_live(*ctx, live)
        };

        if result_ptr.is_null() {
            return Err(CoreError::Transcription("Live streaming transcription failed".to_string()));
        }

        unsafe {
            let text = CStr::from_ptr(result_ptr)
                .to_string_lossy()
                .into_owned();
            libc::free(result_ptr as *mut c_void);
            Ok(text)
        }
    }
}

/// Trampoline function for token callbacks
unsafe extern "C" fn token_callback_trampoline<F>(token: *const c_char, userdata: *mut c_void)
where
    F: FnMut(String),
{
    if token.is_null() || userdata.is_null() {
        return;
    }

    let token_str = CStr::from_ptr(token).to_string_lossy().into_owned();
    let callback = &mut *(userdata as *mut F);
    callback(token_str);
}

impl Drop for QwenTranscriber {
    fn drop(&mut self) {
        let ctx = self.ctx.lock().unwrap();
        unsafe {
            qwen_free(*ctx);
        }
    }
}

/*! Qwen3-ASR C 库的 Rust FFI 绑定
 *
 * 基于 antirez/qwen-asr: https://github.com/antirez/qwen-asr
 */

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int, c_void};
use std::path::Path;

use crate::error::CoreError;

// C 类型定义
pub type QwenContext = c_void;

extern "C" {
    // 加载/释放模型
    fn qwen_load(model_dir: *const c_char) -> *mut QwenContext;
    fn qwen_free(ctx: *mut QwenContext);

    // 设置强制语言
    fn qwen_set_force_language(ctx: *mut QwenContext, language: *const c_char) -> c_int;

    // 转录接口
    fn qwen_transcribe_audio(
        ctx: *mut QwenContext,
        samples: *const c_float,
        n_samples: c_int,
    ) -> *mut c_char;
}

/// Qwen3-ASR 转录器
pub struct QwenTranscriber {
    ctx: *mut QwenContext,
}

unsafe impl Send for QwenTranscriber {}
unsafe impl Sync for QwenTranscriber {}

impl QwenTranscriber {
    /// 加载模型
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

    /// 设置强制语言
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

    /// 转录原始音频样本（16kHz mono f32）
    pub fn transcribe_samples(
        &self,
        samples: &[f32],
        _sample_rate: u32,
        language: Option<&str>,
    ) -> Result<String, CoreError> {
        // 先设置语言（如果有）
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

            // 释放 C 分配的字符串
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

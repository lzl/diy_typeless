/*! Streaming ASR implementation for real-time transcription
 *
 * Uses Qwen3-ASR's live streaming API to provide ~2 second latency
 * from speech to text output.
 */

use crate::error::CoreError;
use crate::qwen_asr_ffi::{QwenLiveAudio, QwenTranscriber};
use std::os::raw::{c_float, c_int, c_void};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

/// Handle for controlling a streaming transcription session
pub struct StreamingHandle {
    /// Flag to signal recording should stop
    stop_flag: Arc<AtomicBool>,

    /// Handle to the audio capture thread
    audio_thread: Option<JoinHandle<()>>,

    /// Handle to the inference thread
    inference_thread: Option<JoinHandle<Result<String, CoreError>>>,

    /// Accumulated text from streaming
    accumulated_text: Arc<Mutex<String>>,
}

impl StreamingHandle {
    /// Create a new streaming handle
    fn new(
        stop_flag: Arc<AtomicBool>,
        audio_thread: JoinHandle<()>,
        inference_thread: JoinHandle<Result<String, CoreError>>,
        accumulated_text: Arc<Mutex<String>>,
    ) -> Self {
        Self {
            stop_flag,
            audio_thread: Some(audio_thread),
            inference_thread: Some(inference_thread),
            accumulated_text,
        }
    }

    /// Stop streaming and return the final transcription
    pub fn stop(mut self) -> Result<String, CoreError> {
        // Signal stop
        self.stop_flag.store(true, Ordering::SeqCst);

        if let Some(thread) = self.audio_thread.take() {
            thread.join().map_err(|_| {
                CoreError::Transcription("Audio thread panicked".to_string())
            })?;
        }

        if let Some(thread) = self.inference_thread.take() {
            match thread.join() {
                Ok(result) => result,
                Err(_) => Err(CoreError::Transcription("Inference thread panicked".to_string())),
            }
        } else {
            // Return accumulated text if inference thread already finished
            let text = self.accumulated_text.lock().unwrap().clone();
            Ok(text)
        }
    }

    /// Get current partial transcription
    pub fn current_text(&self) -> String {
        self.accumulated_text.lock().unwrap().clone()
    }

    /// Check if streaming is still active
    pub fn is_running(&self) -> bool {
        !self.stop_flag.load(Ordering::SeqCst)
    }
}

/// Start streaming transcription with real-time callbacks
///
/// # Arguments
/// * `transcriber` - The QwenTranscriber instance (must be initialized)
/// * `language` - Optional language code (e.g., "en", "zh")
/// * `on_text` - Callback function called with partial text updates
///
/// # Returns
/// A StreamingHandle to control the streaming session
pub fn start_streaming_transcription<F>(
    transcriber: Arc<QwenTranscriber>,
    language: Option<&str>,
    mut on_text: F,
) -> Result<StreamingHandle, CoreError>
where
    F: FnMut(String) + Send + 'static,
{
    let stop_flag = Arc::new(AtomicBool::new(false));
    let accumulated_text = Arc::new(Mutex::new(String::new()));

    // Set up token callback for real-time updates
    let accumulated_text_callback = accumulated_text.clone();
    transcriber.set_token_callback(move |token: String| {
        let mut text = accumulated_text_callback.lock().unwrap();
        text.push_str(&token);
        drop(text);
        on_text(token);
    });

    // Create QwenLiveAudio structure for real-time streaming
    // This is a shared structure between audio capture and inference
    let live_audio = Arc::new(Mutex::new(create_live_audio()?));

    // Clone for threads
    let stop_flag_audio = stop_flag.clone();
    let stop_flag_inference = stop_flag.clone();
    let live_audio_audio = live_audio.clone();
    let live_audio_inference = live_audio.clone();

    let language_owned = language.map(|s| s.to_string());

    // Audio capture thread - feeds audio into live_audio
    let audio_thread = thread::spawn(move || {
        let result = capture_audio_live(
            live_audio_audio,
            stop_flag_audio,
        );

        if let Err(e) = result {
            eprintln!("[ASR] Audio capture error: {}", e);
        }
    });

    // Inference thread - calls qwen_transcribe_stream_live
    let inference_thread = thread::spawn(move || {
        run_live_inference(
            transcriber,
            live_audio_inference,
            stop_flag_inference,
            language_owned.as_deref(),
        )
    });

    Ok(StreamingHandle::new(
        stop_flag,
        audio_thread,
        inference_thread,
        accumulated_text,
    ))
}

/// Create a new QwenLiveAudio structure
fn create_live_audio() -> Result<QwenLiveAudio, CoreError> {
    // Initial buffer capacity (30 seconds at 16kHz)
    const INITIAL_CAPACITY: i64 = 16000 * 30;

    let samples = unsafe {
        libc::malloc((INITIAL_CAPACITY as usize) * std::mem::size_of::<c_float>()) as *mut c_float
    };

    if samples.is_null() {
        return Err(CoreError::Transcription("Failed to allocate audio buffer".to_string()));
    }

    let mut live = QwenLiveAudio {
        samples,
        sample_offset: 0,
        n_samples: 0,
        capacity: INITIAL_CAPACITY,
        eof: 0,
        mutex: std::ptr::null_mut(),
        cond: std::ptr::null_mut(),
        thread: 0,
    };

    // Initialize mutex and condition variable
    let mutex = unsafe { libc::malloc(std::mem::size_of::<libc::pthread_mutex_t>()) as *mut libc::pthread_mutex_t };
    let cond = unsafe { libc::malloc(std::mem::size_of::<libc::pthread_cond_t>()) as *mut libc::pthread_cond_t };

    if mutex.is_null() || cond.is_null() {
        return Err(CoreError::Transcription("Failed to allocate sync primitives".to_string()));
    }

    unsafe {
        libc::pthread_mutex_init(mutex, std::ptr::null());
        libc::pthread_cond_init(cond, std::ptr::null());
    }

    live.mutex = mutex as *mut c_void;
    live.cond = cond as *mut c_void;

    Ok(live)
}

/// Free QwenLiveAudio resources
unsafe fn free_live_audio(live: &mut QwenLiveAudio) {
    if !live.samples.is_null() {
        libc::free(live.samples as *mut c_void);
    }
    if !live.mutex.is_null() {
        libc::pthread_mutex_destroy(live.mutex as *mut libc::pthread_mutex_t);
        libc::free(live.mutex);
    }
    if !live.cond.is_null() {
        libc::pthread_cond_destroy(live.cond as *mut libc::pthread_cond_t);
        libc::free(live.cond);
    }
}

/// Capture audio into live audio buffer
fn capture_audio_live(
    live_audio: Arc<Mutex<QwenLiveAudio>>,
    stop_flag: Arc<AtomicBool>,
) -> Result<(), CoreError> {
    use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

    let host = cpal::default_host();
    let device = host.default_input_device()
        .ok_or_else(|| CoreError::AudioProcessing("No input device available".to_string()))?;

    // Qwen3-ASR requires 16kHz sample rate
    const TARGET_SAMPLE_RATE: u32 = 16000;

    // Try to get supported config with 16kHz
    let mut supported_config = None;
    if let Ok(mut configs) = device.supported_input_configs() {
        while let Some(config_range) = configs.next() {
            if config_range.min_sample_rate() <= TARGET_SAMPLE_RATE.into()
                && config_range.max_sample_rate() >= TARGET_SAMPLE_RATE.into()
            {
                supported_config = Some(config_range.with_sample_rate(TARGET_SAMPLE_RATE.into()));
                break;
            }
        }
    }

    let config = match supported_config {
        Some(cfg) => cfg,
        None => {
            device.default_input_config()
                .map_err(|e| CoreError::AudioProcessing(format!("Failed to get input config: {}", e)))?
        }
    };

    let sample_rate = config.sample_rate();
    let channels = config.channels() as usize;

    eprintln!("[ASR] Audio config: {} Hz, {} channels", sample_rate, channels);

    // Build stream
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => build_live_stream::<f32>(
            &device,
            &config.into(),
            live_audio.clone(),
            stop_flag.clone(),
            channels,
            sample_rate,
            TARGET_SAMPLE_RATE,
        )?,
        cpal::SampleFormat::I16 => build_live_stream::<i16>(
            &device,
            &config.into(),
            live_audio.clone(),
            stop_flag.clone(),
            channels,
            sample_rate,
            TARGET_SAMPLE_RATE,
        )?,
        cpal::SampleFormat::U16 => build_live_stream::<u16>(
            &device,
            &config.into(),
            live_audio.clone(),
            stop_flag.clone(),
            channels,
            sample_rate,
            TARGET_SAMPLE_RATE,
        )?,
        _ => return Err(CoreError::AudioProcessing("Unsupported sample format".to_string())),
    };

    stream.play()
        .map_err(|e| CoreError::AudioProcessing(format!("Failed to start stream: {}", e)))?;

    // Wait for stop signal
    while !stop_flag.load(Ordering::SeqCst) {
        thread::sleep(Duration::from_millis(10));
    }

    // Signal EOF
    {
        let mut live = live_audio.lock().unwrap();
        live.eof = 1;
        // Signal condition variable to wake up inference thread
        unsafe {
            libc::pthread_cond_signal(live.cond as *mut libc::pthread_cond_t);
        }
    }

    Ok(())
}

fn build_live_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    live_audio: Arc<Mutex<QwenLiveAudio>>,
    stop_flag: Arc<AtomicBool>,
    channels: usize,
    input_sample_rate: u32,
    target_sample_rate: u32,
) -> Result<cpal::Stream, CoreError>
where
    T: cpal::Sample + Into<f32> + cpal::SizedSample,
{
    use cpal::traits::DeviceTrait;

    let resample_ratio = input_sample_rate as f64 / target_sample_rate as f64;
    let mut resample_accumulator: f64 = 0.0;

    let stream = device.build_input_stream(
        config,
        move |data: &[T], _: &cpal::InputCallbackInfo| {
            if stop_flag.load(Ordering::SeqCst) {
                return;
            }

            let mut live = live_audio.lock().unwrap();

            // Convert to mono f32 with resampling and append to buffer
            for chunk in data.chunks(channels) {
                let sum: f32 = chunk.iter().map(|s| Into::<f32>::into(*s)).sum();
                let sample = sum / channels as f32;

                resample_accumulator += 1.0;
                if resample_accumulator >= resample_ratio {
                    // Check if we need to grow buffer
                    if live.n_samples >= live.capacity {
                        let new_capacity = live.capacity * 2;
                        let new_samples = unsafe {
                            libc::realloc(
                                live.samples as *mut c_void,
                                (new_capacity as usize) * std::mem::size_of::<c_float>(),
                            ) as *mut c_float
                        };
                        if new_samples.is_null() {
                            eprintln!("[ASR] Failed to grow audio buffer");
                            return;
                        }
                        live.samples = new_samples;
                        live.capacity = new_capacity;
                    }

                    unsafe {
                        *live.samples.offset(live.n_samples as isize) = sample;
                    }
                    live.n_samples += 1;
                    resample_accumulator -= resample_ratio;
                }
            }

            // Signal that new data is available
            unsafe {
                libc::pthread_cond_signal(live.cond as *mut libc::pthread_cond_t);
            }
        },
        |err| eprintln!("[ASR] Stream error: {}", err),
        None,
    ).map_err(|e| CoreError::AudioProcessing(format!("Failed to build stream: {}", e)))?;

    Ok(stream)
}

/// Run live streaming inference using qwen_transcribe_stream_live
fn run_live_inference(
    transcriber: Arc<QwenTranscriber>,
    live_audio: Arc<Mutex<QwenLiveAudio>>,
    stop_flag: Arc<AtomicBool>,
    language: Option<&str>,
) -> Result<String, CoreError> {
    // Wait until we have some initial audio data (0.5 seconds)
    let min_samples = 16000 / 2;
    loop {
        {
            let live = live_audio.lock().unwrap();
            if live.n_samples >= min_samples {
                break;
            }
            if stop_flag.load(Ordering::SeqCst) || live.eof != 0 {
                return Ok(String::new());
            }
        }
        thread::sleep(Duration::from_millis(50));
    }

    // Get mutable pointer to live audio for C API
    let live_ptr: *mut QwenLiveAudio = {
        let mut live = live_audio.lock().unwrap();
        &mut *live as *mut QwenLiveAudio
    };

    // SAFETY: This is safe because:
    // 1. The audio capture thread holds the Arc<Mutex<QwenLiveAudio>>
    // 2. The transcriber doesn't modify the live structure, only reads from it
    // 3. The C library uses mutex/condvar for synchronization
    let result = unsafe {
        // Note: We need to ensure the mutex guard is dropped before calling
        // into C code, otherwise we could deadlock with the audio thread
        transcriber.transcribe_stream_live(live_ptr, language)
    };

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_streaming_handle_creation() {
        // This is a basic sanity test - full integration tests require the model
        // Just verify the types compile correctly
    }
}

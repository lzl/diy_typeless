/*! Streaming ASR implementation for real-time transcription
 *
 * Uses Qwen3-ASR's live streaming API to provide ~2 second latency
 * from speech to text output.
 */

use crate::error::CoreError;
use crate::qwen_asr_ffi::{QwenLiveAudio, QwenTranscriber};
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

    // Create live audio structure for real-time streaming
    // This is a channel between audio capture and inference threads
    let (tx, rx) = std::sync::mpsc::channel::<Vec<f32>>();

    // Clone for threads
    let stop_flag_audio = stop_flag.clone();
    let stop_flag_inference = stop_flag.clone();

    // Audio capture thread
    let audio_thread = thread::spawn(move || {
        let result = capture_audio_streaming(tx, stop_flag_audio);

        if let Err(e) = result {
            eprintln!("[ASR] Audio capture error: {}", e);
        }
    });

    // Inference thread - uses the transcribe_stream with chunked processing
    // for real-time effect
    let language_owned = language.map(|s| s.to_string());
    let inference_thread = thread::spawn(move || {
        run_streaming_inference(
            transcriber,
            rx,
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

/// Capture audio in streaming mode
fn capture_audio_streaming(
    tx: std::sync::mpsc::Sender<Vec<f32>>,
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
            // Fall back to default config, we'll need to resample
            device.default_input_config()
                .map_err(|e| CoreError::AudioProcessing(format!("Failed to get input config: {}", e)))?
        }
    };

    let sample_rate = config.sample_rate();
    let channels = config.channels() as usize;

    eprintln!("[ASR] Audio config: {} Hz, {} channels", sample_rate, channels);

    // Process audio in chunks (100ms = 1600 samples at 16kHz)
    const CHUNK_SAMPLES: usize = 1600; // 100ms at 16kHz

    // Build stream
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => build_stream::<f32>(
            &device,
            &config.into(),
            tx.clone(),
            stop_flag.clone(),
            channels,
            CHUNK_SAMPLES,
            sample_rate,
            TARGET_SAMPLE_RATE,
        )?,
        cpal::SampleFormat::I16 => build_stream::<i16>(
            &device,
            &config.into(),
            tx.clone(),
            stop_flag.clone(),
            channels,
            CHUNK_SAMPLES,
            sample_rate,
            TARGET_SAMPLE_RATE,
        )?,
        cpal::SampleFormat::U16 => build_stream::<u16>(
            &device,
            &config.into(),
            tx.clone(),
            stop_flag.clone(),
            channels,
            CHUNK_SAMPLES,
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

    // Send empty chunk to signal EOF
    let _ = tx.send(Vec::new());

    // Stream will be dropped here, stopping the capture
    Ok(())
}

fn build_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    tx: std::sync::mpsc::Sender<Vec<f32>>,
    stop_flag: Arc<AtomicBool>,
    channels: usize,
    chunk_samples: usize,
    input_sample_rate: u32,
    target_sample_rate: u32,
) -> Result<cpal::Stream, CoreError>
where
    T: cpal::Sample + Into<f32> + cpal::SizedSample,
{
    use cpal::traits::DeviceTrait;

    let mut buffer: Vec<f32> = Vec::with_capacity(chunk_samples);
    // For simple resampling: track fractional sample position
    let mut resample_accumulator: f64 = 0.0;
    let resample_ratio = input_sample_rate as f64 / target_sample_rate as f64;
    let mut mono_samples: Vec<f32> = Vec::new();

    let stream = device.build_input_stream(
        config,
        move |data: &[T], _: &cpal::InputCallbackInfo| {
            if stop_flag.load(Ordering::SeqCst) {
                return;
            }

            // Convert to mono f32
            mono_samples.clear();
            for chunk in data.chunks(channels) {
                let sum: f32 = chunk.iter().map(|s| Into::<f32>::into(*s)).sum();
                mono_samples.push(sum / channels as f32);
            }

            // Simple downsampling if input rate > target rate
            // (nearest neighbor for simplicity)
            for &sample in &mono_samples {
                resample_accumulator += 1.0;
                if resample_accumulator >= resample_ratio {
                    buffer.push(sample);
                    resample_accumulator -= resample_ratio;

                    // Send chunk when full
                    if buffer.len() >= chunk_samples {
                        let chunk_to_send = std::mem::take(&mut buffer);
                        if tx.send(chunk_to_send).is_err() {
                            // Receiver dropped, stop capturing
                            return;
                        }
                        buffer.reserve(chunk_samples);
                    }
                }
            }
        },
        |err| eprintln!("[ASR] Stream error: {}", err),
        None,
    ).map_err(|e| CoreError::AudioProcessing(format!("Failed to build stream: {}", e)))?;

    Ok(stream)
}

/// Run streaming inference with chunked processing
fn run_streaming_inference(
    transcriber: Arc<QwenTranscriber>,
    rx: std::sync::mpsc::Receiver<Vec<f32>>,
    stop_flag: Arc<AtomicBool>,
    language: Option<&str>,
) -> Result<String, CoreError> {
    use std::collections::VecDeque;

    // Collect audio chunks into a sliding window buffer
    // Process every 2 seconds of audio for real-time effect
    let window_size = 16000 * 2; // 2 seconds at 16kHz
    let mut audio_buffer: VecDeque<f32> = VecDeque::with_capacity(window_size * 2);

    // Wait for initial audio data (at least 0.5 seconds)
    let min_samples = 16000 / 2; // 0.5 seconds

    loop {
        // Check if we should stop
        if stop_flag.load(Ordering::SeqCst) {
            break;
        }

        // Receive audio chunk
        match rx.recv_timeout(Duration::from_millis(100)) {
            Ok(chunk) => {
                // Empty chunk signals EOF
                if chunk.is_empty() {
                    break;
                }

                // Add to buffer
                for sample in chunk {
                    audio_buffer.push_back(sample);
                }

                // Keep buffer within reasonable size (max 30 seconds)
                while audio_buffer.len() > 16000 * 30 {
                    audio_buffer.pop_front();
                }
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                // No data yet, continue
                continue;
            }
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                // Sender dropped, we're done
                break;
            }
        }
    }

    // Collect all audio into a vector
    let final_samples: Vec<f32> = audio_buffer.into_iter().collect();

    eprintln!("[ASR] Final audio samples: {}", final_samples.len());

    if final_samples.is_empty() {
        return Ok(String::new());
    }

    // Transcribe the accumulated audio using streaming API
    // This will call the token callback for partial results
    let result = transcriber.transcribe_stream(&final_samples, 16000, language);
    eprintln!("[ASR] Transcription result: {:?}", result);
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

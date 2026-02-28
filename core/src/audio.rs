use crate::config::{HIGHPASS_FREQ_HZ, TARGET_RMS_DB, WHISPER_CHANNELS, WHISPER_SAMPLE_RATE};
use crate::error::CoreError;
use biquad::{Biquad, Coefficients, DirectForm1, ToHertz, Type, Q_BUTTERWORTH_F32};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{Arc, LazyLock, Mutex};

#[derive(Debug, uniffi::Record)]
#[must_use]
pub struct AudioData {
    pub bytes: Vec<u8>,
    pub duration_seconds: f32,
}

struct RecordingState {
    is_recording: bool,
    stream: Option<cpal::Stream>,
    samples: Arc<Mutex<Vec<f32>>>,
    sample_rate: u32,
    channels: u16,
}

impl RecordingState {
    fn new() -> Self {
        Self {
            is_recording: false,
            stream: None,
            samples: Arc::new(Mutex::new(Vec::new())),
            sample_rate: WHISPER_SAMPLE_RATE,
            channels: WHISPER_CHANNELS,
        }
    }
}

static RECORDING_STATE: LazyLock<Mutex<RecordingState>> =
    LazyLock::new(|| Mutex::new(RecordingState::new()));

pub fn start_recording() -> Result<(), CoreError> {
    let mut state = RECORDING_STATE
        .lock()
        .map_err(|_| CoreError::AudioCapture("Recording lock poisoned".to_string()))?;

    if state.is_recording {
        return Err(CoreError::RecordingAlreadyActive);
    }

    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or(CoreError::AudioDeviceUnavailable)?;
    let supported_config = device
        .default_input_config()
        .map_err(|e| CoreError::AudioCapture(e.to_string()))?;

    let sample_format = supported_config.sample_format();
    let config: cpal::StreamConfig = supported_config.into();

    let sample_rate = config.sample_rate;
    let channels = config.channels;

    let samples = Arc::new(Mutex::new(Vec::new()));
    let samples_for_stream = samples.clone();

    let err_fn = |err| log::error!("Audio stream error: {err}");

    let stream = match sample_format {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config,
            move |data: &[f32], _| capture_f32(data, channels, &samples_for_stream),
            err_fn,
            None,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config,
            move |data: &[i16], _| capture_i16(data, channels, &samples_for_stream),
            err_fn,
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config,
            move |data: &[u16], _| capture_u16(data, channels, &samples_for_stream),
            err_fn,
            None,
        ),
        _ => Err(cpal::BuildStreamError::StreamConfigNotSupported),
    }
    .map_err(|e| CoreError::AudioCapture(e.to_string()))?;

    stream
        .play()
        .map_err(|e| CoreError::AudioCapture(e.to_string()))?;

    state.is_recording = true;
    state.stream = Some(stream);
    state.samples = samples;
    state.sample_rate = sample_rate;
    state.channels = channels;

    Ok(())
}

pub fn stop_recording() -> Result<AudioData, CoreError> {
    let mut state = RECORDING_STATE
        .lock()
        .map_err(|_| CoreError::AudioCapture("Recording lock poisoned".to_string()))?;

    if !state.is_recording {
        return Err(CoreError::RecordingNotActive);
    }

    state.is_recording = false;
    // SAFETY: The stream must be dropped before locking `samples` to avoid deadlock.
    // The audio callback holds the `samples` lock while writing; if we lock `samples`
    // first, the callback would block on `samples` while we block on stream teardown.
    if let Some(stream) = state.stream.take() {
        drop(stream);
    }

    let samples = state
        .samples
        .lock()
        .map_err(|_| CoreError::AudioCapture("Sample lock poisoned".to_string()))?;
    if samples.is_empty() {
        return Err(CoreError::AudioCapture("No audio captured".to_string()));
    }

    let mut captured = samples.clone();
    drop(samples);

    let duration_seconds = captured.len() as f32 / state.sample_rate as f32;

    if state.sample_rate != WHISPER_SAMPLE_RATE {
        captured = resample_linear(&captured, state.sample_rate, WHISPER_SAMPLE_RATE);
    }

    let enhanced = enhance_audio(&captured, WHISPER_SAMPLE_RATE)?;
    let bytes = flac_bytes_from_samples(&enhanced)?;

    Ok(AudioData {
        bytes,
        duration_seconds,
    })
}

fn capture_f32(data: &[f32], channels: u16, samples: &Arc<Mutex<Vec<f32>>>) {
    let mut buffer = match samples.lock() {
        Ok(buffer) => buffer,
        Err(_) => return,
    };

    if channels == 1 {
        buffer.extend_from_slice(data);
        return;
    }

    let channels = channels as usize;
    for frame in data.chunks(channels) {
        let mut sum = 0.0f32;
        for sample in frame {
            sum += *sample;
        }
        buffer.push(sum / channels as f32);
    }
}

fn capture_i16(data: &[i16], channels: u16, samples: &Arc<Mutex<Vec<f32>>>) {
    let mut buffer = match samples.lock() {
        Ok(buffer) => buffer,
        Err(_) => return,
    };

    let scale = i16::MAX as f32;
    if channels == 1 {
        buffer.extend(data.iter().map(|s| *s as f32 / scale));
        return;
    }

    let channels = channels as usize;
    for frame in data.chunks(channels) {
        let mut sum = 0.0f32;
        for sample in frame {
            sum += *sample as f32 / scale;
        }
        buffer.push(sum / channels as f32);
    }
}

fn capture_u16(data: &[u16], channels: u16, samples: &Arc<Mutex<Vec<f32>>>) {
    let mut buffer = match samples.lock() {
        Ok(buffer) => buffer,
        Err(_) => return,
    };

    let scale = u16::MAX as f32;
    if channels == 1 {
        buffer.extend(data.iter().map(|s| (*s as f32 / scale) * 2.0 - 1.0));
        return;
    }

    let channels = channels as usize;
    for frame in data.chunks(channels) {
        let mut sum = 0.0f32;
        for sample in frame {
            sum += (*sample as f32 / scale) * 2.0 - 1.0;
        }
        buffer.push(sum / channels as f32);
    }
}

fn resample_linear(input: &[f32], src_rate: u32, dst_rate: u32) -> Vec<f32> {
    if input.is_empty() || src_rate == dst_rate {
        return input.to_vec();
    }

    let ratio = src_rate as f64 / dst_rate as f64;
    let output_len = ((input.len() as f64) / ratio).floor() as usize;

    let mut output = Vec::with_capacity(output_len.max(1));
    for i in 0..output_len {
        let src_pos = i as f64 * ratio;
        let idx = src_pos.floor() as usize;
        let frac = (src_pos - idx as f64) as f32;
        let s0 = input.get(idx).copied().unwrap_or(0.0);
        let s1 = input.get(idx + 1).copied().unwrap_or(s0);
        output.push(s0 + (s1 - s0) * frac);
    }

    output
}

/// Optimized audio enhancement for ASR input.
///
/// Applies minimal processing to improve recognition while avoiding
/// unnecessary gain staging that amplifies noise.
fn enhance_audio(samples: &[f32], sample_rate: u32) -> Result<Vec<f32>, CoreError> {
    if samples.is_empty() {
        return Ok(Vec::new());
    }

    let mut output = samples.to_vec();

    // Step 1: Highpass filter to remove low-frequency rumble/noise
    if let Ok(coeffs) = Coefficients::<f32>::from_params(
        Type::HighPass,
        sample_rate.hz(),
        HIGHPASS_FREQ_HZ.hz(),
        Q_BUTTERWORTH_F32,
    ) {
        let mut df1 = DirectForm1::<f32>::new(coeffs);
        for sample in &mut output {
            *sample = df1.run(*sample);
        }
    }

    // Step 2: RMS normalization to ensure consistent volume
    // This is critical for whisper speech recognition - too quiet = poor accuracy
    let rms = (output.iter().map(|s| s * s).sum::<f32>() / output.len() as f32).sqrt();
    if rms > 1e-6 {
        let target_rms = 10f32.powf(TARGET_RMS_DB / 20.0);
        let gain = (target_rms / rms).min(10.0); // Cap gain at 10x to prevent extreme amplification
        for sample in &mut output {
            *sample *= gain;
        }
    }

    Ok(output)
}

/// Stop recording and return audio encoded as WAV (for CLI testing).
///
/// This preserves the original WAV format for compatibility with
/// existing diagnostic tools and external audio processing.
pub fn stop_recording_wav() -> Result<AudioData, CoreError> {
    let mut state = RECORDING_STATE
        .lock()
        .map_err(|_| CoreError::AudioCapture("Recording lock poisoned".to_string()))?;

    if !state.is_recording {
        return Err(CoreError::RecordingNotActive);
    }

    state.is_recording = false;
    if let Some(stream) = state.stream.take() {
        drop(stream);
    }

    let samples = state
        .samples
        .lock()
        .map_err(|_| CoreError::AudioCapture("Sample lock poisoned".to_string()))?;
    if samples.is_empty() {
        return Err(CoreError::AudioCapture("No audio captured".to_string()));
    }

    let mut captured = samples.clone();
    drop(samples);

    let duration_seconds = captured.len() as f32 / state.sample_rate as f32;

    if state.sample_rate != WHISPER_SAMPLE_RATE {
        captured = resample_linear(&captured, state.sample_rate, WHISPER_SAMPLE_RATE);
    }

    let enhanced = enhance_audio(&captured, WHISPER_SAMPLE_RATE)?;
    let bytes = wav_bytes_from_samples(&enhanced)?;

    Ok(AudioData {
        bytes,
        duration_seconds,
    })
}

fn wav_bytes_from_samples(samples: &[f32]) -> Result<Vec<u8>, CoreError> {
    use std::io::Cursor;

    let spec = hound::WavSpec {
        channels: WHISPER_CHANNELS,
        sample_rate: WHISPER_SAMPLE_RATE,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut writer = hound::WavWriter::new(&mut cursor, spec)
            .map_err(|e| CoreError::AudioProcessing(e.to_string()))?;
        for sample in samples {
            let scaled = (sample * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i16;
            writer
                .write_sample(scaled)
                .map_err(|e| CoreError::AudioProcessing(e.to_string()))?;
        }
        writer
            .finalize()
            .map_err(|e| CoreError::AudioProcessing(e.to_string()))?;
    }

    Ok(cursor.into_inner())
}

/// Encode audio samples to FLAC format for efficient upload.
///
/// FLAC provides ~50-70% compression ratio for speech audio,
/// significantly reducing upload time compared to uncompressed WAV.
fn flac_bytes_from_samples(samples: &[f32]) -> Result<Vec<u8>, CoreError> {
    use flacenc::bitsink::ByteSink;
    use flacenc::component::BitRepr;

    // Convert f32 samples to i32 as expected by FLAC
    let i32_samples: Vec<i32> = samples
        .iter()
        .map(|s| (s * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i32)
        .collect();

    // Create encoder config (uses default compression level)
    let config = flacenc::config::Encoder::default();

    // Create a source from the interleaved i32 samples
    let source = flacenc::source::MemSource::from_samples(
        &i32_samples,
        WHISPER_CHANNELS as usize,
        16, // bits per sample
        WHISPER_SAMPLE_RATE as usize,
    );

    // Encode to FLAC
    let flac_stream = flacenc::encode_with_fixed_block_size(
        &config,
        source,
        config.block_sizes[0],
    )
    .map_err(|e| CoreError::AudioProcessing(format!("FLAC encoding error: {:?}", e)))?;

    // Write to byte sink
    let mut sink = ByteSink::new();
    flac_stream
        .write(&mut sink)
        .map_err(|e| CoreError::AudioProcessing(format!("FLAC write error: {}", e)))?;

    Ok(sink.as_slice().to_vec())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    #[test]
    fn resample_linear_empty_input_returns_empty() {
        let input: Vec<f32> = vec![];
        let result = resample_linear(&input, 16000, 16000);
        assert!(result.is_empty());
    }

    #[test]
    fn resample_linear_same_sample_rate_returns_clone() {
        let input = vec![0.5, -0.5, 0.25, -0.25];
        let result = resample_linear(&input, 16000, 16000);
        assert_eq!(result, input);
    }

    #[test]
    fn resample_linear_downsample_reduces_length() {
        // 10 samples at 48000 Hz -> 16000 Hz should produce ~3 samples
        let input = vec![0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
        let result = resample_linear(&input, 48000, 16000);
        // 48000/16000 = 3.0 ratio, so 10/3 = ~3 samples
        assert_eq!(result.len(), 3);
    }

    #[test]
    fn resample_linear_upsample_increases_length() {
        // 3 samples at 16000 Hz -> 48000 Hz should produce ~9 samples
        let input = vec![0.0, 0.5, 1.0];
        let result = resample_linear(&input, 16000, 48000);
        // 16000/48000 = 0.333 ratio, so 3/0.333 = ~9 samples
        assert_eq!(result.len(), 9);
    }

    #[test]
    fn resample_linear_interpolation_is_linear() {
        // Linear ramp from 0.0 to 1.0 at 48000 Hz -> 24000 Hz
        // Should produce interpolated values
        let input = vec![0.0, 0.5, 1.0];
        let result = resample_linear(&input, 48000, 24000);
        // At 2:1 ratio, we get ~1.5 samples -> 1 sample after floor
        assert!(!result.is_empty());
        // The first sample should be close to 0.0 (start of interpolation)
        assert!((result[0] - 0.0).abs() < 0.01);
    }

    #[test]
    fn enhance_audio_empty_input_returns_empty() {
        let input: Vec<f32> = vec![];
        let result = enhance_audio(&input, 16000).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn enhance_audio_preserves_sample_count() {
        let input = vec![0.1, -0.1, 0.2, -0.2, 0.3];
        let result = enhance_audio(&input, 16000).unwrap();
        assert_eq!(result.len(), input.len());
    }

    #[test]
    fn enhance_audio_applies_rms_normalization() {
        // Very quiet signal should be amplified
        let input = vec![0.001, -0.001, 0.001, -0.001];
        let result = enhance_audio(&input, 16000).unwrap();
        // The RMS should be higher in the output
        let input_rms: f32 = (input.iter().map(|s| s * s).sum::<f32>() / input.len() as f32).sqrt();
        let output_rms: f32 =
            (result.iter().map(|s| s * s).sum::<f32>() / result.len() as f32).sqrt();
        assert!(output_rms > input_rms);
    }

    #[test]
    fn capture_f32_mono_copies_directly() {
        let samples = Arc::new(Mutex::new(Vec::new()));
        let data = vec![0.5, -0.5, 0.25, -0.25];
        capture_f32(&data, 1, &samples);
        let locked = samples.lock().unwrap();
        assert_eq!(*locked, data);
    }

    #[test]
    fn capture_f32_stereo_averages_channels() {
        let samples = Arc::new(Mutex::new(Vec::new()));
        // Stereo interleaved: [L0, R0, L1, R1, L2, R2]
        let data = vec![0.0, 1.0, 0.5, 0.5, 1.0, 0.0];
        capture_f32(&data, 2, &samples);
        let locked = samples.lock().unwrap();
        // Should average to [0.5, 0.5, 0.5]
        assert_eq!(*locked, vec![0.5, 0.5, 0.5]);
    }

    #[test]
    fn capture_f32_quad_averages_four_channels() {
        let samples = Arc::new(Mutex::new(Vec::new()));
        // Quad interleaved: [C0, C1, C2, C3, C0, C1, C2, C3]
        let data = vec![0.0, 0.4, 0.8, 1.2, 0.2, 0.6, 1.0, 1.4];
        capture_f32(&data, 4, &samples);
        let locked = samples.lock().unwrap();
        // Should average: [(0.0+0.4+0.8+1.2)/4=0.6, (0.2+0.6+1.0+1.4)/4=0.8]
        assert_eq!(locked.len(), 2);
        assert!((locked[0] - 0.6).abs() < f32::EPSILON);
        assert!((locked[1] - 0.8).abs() < 0.0001);
    }
}

use crate::config::{
    HIGHPASS_FREQ_HZ, MAX_GAIN, PEAK_NORMALIZE_TARGET, SOFT_LIMIT_THRESHOLD, TARGET_RMS_DB,
    WHISPER_CHANNELS, WHISPER_SAMPLE_RATE,
};
use crate::error::CoreError;
use biquad::{Biquad, Coefficients, DirectForm1, ToHertz, Type, Q_BUTTERWORTH_F32};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use once_cell::sync::Lazy;
use std::io::Cursor;
use std::sync::{Arc, Mutex};

#[derive(Debug, uniffi::Record)]
pub struct WavData {
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

static RECORDING_STATE: Lazy<Mutex<RecordingState>> =
    Lazy::new(|| Mutex::new(RecordingState::new()));

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

pub fn stop_recording() -> Result<WavData, CoreError> {
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
    let bytes = wav_bytes_from_samples(&enhanced)?;

    Ok(WavData {
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

fn enhance_audio(samples: &[f32], sample_rate: u32) -> Result<Vec<f32>, CoreError> {
    if samples.is_empty() {
        return Ok(Vec::new());
    }

    let mut output = samples.to_vec();

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

    let rms = (output.iter().map(|s| s * s).sum::<f32>() / output.len() as f32).sqrt();
    if rms > 1e-6 {
        let target_rms = 10f32.powf(TARGET_RMS_DB / 20.0);
        let mut gain = target_rms / rms;
        if gain > MAX_GAIN {
            gain = MAX_GAIN;
        }
        for sample in &mut output {
            *sample *= gain;
        }
    }

    for sample in &mut output {
        let abs = sample.abs();
        if abs > SOFT_LIMIT_THRESHOLD {
            let compressed = SOFT_LIMIT_THRESHOLD
                + (1.0 - SOFT_LIMIT_THRESHOLD)
                    * ((abs - SOFT_LIMIT_THRESHOLD) / (1.0 - SOFT_LIMIT_THRESHOLD)).tanh();
            *sample = sample.signum() * compressed;
        }
    }

    let peak = output
        .iter()
        .fold(0.0f32, |acc, s| if s.abs() > acc { s.abs() } else { acc });
    if peak > 1e-6 {
        let gain = PEAK_NORMALIZE_TARGET / peak;
        for sample in &mut output {
            *sample *= gain;
        }
    }

    Ok(output)
}

fn wav_bytes_from_samples(samples: &[f32]) -> Result<Vec<u8>, CoreError> {
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

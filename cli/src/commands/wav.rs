//! WAV file analysis utilities

use anyhow::{anyhow, Context, Result};
use std::io::Cursor;

/// Metrics extracted from a WAV file
pub struct WavMetrics {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub duration_seconds: f64,
    pub rms_dbfs: f64,
    pub peak_dbfs: f64,
    pub sample_count: usize,
}

/// Inspect WAV bytes and extract metrics
pub fn inspect_wav_bytes(bytes: &[u8]) -> Result<WavMetrics> {
    let mut reader = hound::WavReader::new(Cursor::new(bytes))?;
    let spec = reader.spec();

    if spec.channels == 0 || spec.sample_rate == 0 {
        return Err(anyhow!("Invalid WAV header"));
    }

    let mut sample_count = 0usize;
    let mut sum_square = 0.0f64;
    let mut peak = 0.0f64;

    match spec.sample_format {
        hound::SampleFormat::Float => {
            for sample in reader.samples::<f32>() {
                let normalized = sample.context("Failed to read WAV sample")? as f64;
                sum_square += normalized * normalized;
                peak = peak.max(normalized.abs());
                sample_count += 1;
            }
        }
        hound::SampleFormat::Int => {
            let bits = spec.bits_per_sample;
            if bits <= 16 {
                let denom = max_int_amplitude(bits);
                for sample in reader.samples::<i16>() {
                    let normalized = sample.context("Failed to read WAV sample")? as f64 / denom;
                    sum_square += normalized * normalized;
                    peak = peak.max(normalized.abs());
                    sample_count += 1;
                }
            } else {
                let denom = max_int_amplitude(bits);
                for sample in reader.samples::<i32>() {
                    let normalized = sample.context("Failed to read WAV sample")? as f64 / denom;
                    sum_square += normalized * normalized;
                    peak = peak.max(normalized.abs());
                    sample_count += 1;
                }
            }
        }
    }

    if sample_count == 0 {
        return Err(anyhow!("WAV contains no samples"));
    }

    let channels = spec.channels as usize;
    let frames = sample_count / channels;
    let duration_seconds = frames as f64 / spec.sample_rate as f64;

    let rms = (sum_square / sample_count as f64).sqrt();
    let rms_dbfs = to_dbfs(rms);
    let peak_dbfs = to_dbfs(peak.max(1e-12));

    Ok(WavMetrics {
        sample_rate: spec.sample_rate,
        channels: spec.channels,
        bits_per_sample: spec.bits_per_sample,
        duration_seconds,
        rms_dbfs,
        peak_dbfs,
        sample_count,
    })
}

/// Calculate maximum integer amplitude for normalization
fn max_int_amplitude(bits_per_sample: u16) -> f64 {
    if bits_per_sample <= 1 {
        return 1.0;
    }

    // Keep diagnostic normalization valid for 24/32-bit PCM and avoid shift overflow.
    let shift = (bits_per_sample - 1).min(62) as u32;
    ((1i64 << shift) - 1) as f64
}

/// Convert linear amplitude to dBFS
fn to_dbfs(value: f64) -> f64 {
    if value <= 1e-12 {
        return f64::NEG_INFINITY;
    }
    20.0 * value.log10()
}

#[cfg(test)]
mod tests {
    use super::max_int_amplitude;

    #[test]
    fn max_int_amplitude_handles_16_bit_pcm() {
        assert!((max_int_amplitude(16) - 32767.0).abs() < f64::EPSILON);
    }

    #[test]
    fn max_int_amplitude_handles_32_bit_pcm() {
        assert!((max_int_amplitude(32) - 2_147_483_647.0).abs() < f64::EPSILON);
    }
}

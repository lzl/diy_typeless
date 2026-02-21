# Groq Whisper Transcription Speed Optimization

**Date**: 2025-02-21
**Branch**: `lzl/faster-groq-whisper`
**Author**: Claude Opus 4.6

## Problem Statement

The original Groq Whisper transcription pipeline was fully sequential with significant latency bottlenecks:

1. **TLS Handshake Overhead**: Each request created a new HTTP client, requiring 50-150ms TLS handshake (longer on weak networks)
2. **Large Upload Size**: Uncompressed PCM WAV (96KB for 3s, 960KB for 30s) increased network transmission time
3. **Over-processing**: 4-step audio enhancement (highpass → RMS normalize → soft limit → peak normalize) added unnecessary CPU cycles

**Pipeline Before**:
```
Stop Recording → Audio Enhancement (4 steps) → WAV Encode → New HTTP Client → TLS Handshake → Upload WAV → Wait Response
```

## Optimization Strategy

### Direction 1: HTTP Connection Pooling + TLS Warmup

**Expected Gain**: 100-400ms per request

**Implementation**:
- Created `core/src/http_client.rs` with `OnceLock<Client>` for global client reuse
- Configured `pool_idle_timeout(300s)` + `pool_max_idle_per_host(2)`
- Added `warmup_groq_connection()` and `warmup_gemini_connection()` functions
- Trigger TLS warmup asynchronously when recording starts (`handleKeyDown`)

**Key Code Changes**:
```rust
// http_client.rs
static HTTP_CLIENT: OnceLock<Client> = OnceLock::new();

pub fn get_http_client() -> &'static Client {
    HTTP_CLIENT.get_or_init(|| {
        Client::builder()
            .timeout(Duration::from_secs(90))
            .pool_idle_timeout(Duration::from_secs(300))
            .pool_max_idle_per_host(2)
            .build()
            .expect("Failed to create HTTP client")
    })
}
```

**Swift Integration**:
```swift
// RecordingState.swift
DispatchQueue.global(qos: .background).async { [weak self] in
    _ = try? warmupGroqConnection()
    _ = try? warmupGeminiConnection()
}
```

### Direction 2: FLAC Compression (Instead of WAV)

**Expected Gain**: 50-200ms (depending on network and recording length)

**Why FLAC over Opus/MP3**:
- Lossless compression (no quality loss)
- Pure Rust implementation (`flacenc` crate)
- Groq API officially supports FLAC
- ~50-70% compression ratio for speech audio

**Implementation**:
```rust
fn flac_bytes_from_samples(samples: &[f32]) -> Result<Vec<u8>, CoreError> {
    use flacenc::bitsink::ByteSink;
    use flacenc::component::BitRepr;

    let i32_samples: Vec<i32> = samples
        .iter()
        .map(|s| (s * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i32)
        .collect();

    let config = flacenc::config::Encoder::default();
    let source = flacenc::source::MemSource::from_samples(
        &i32_samples,
        WHISPER_CHANNELS as usize,
        16,
        WHISPER_SAMPLE_RATE as usize,
    );

    let flac_stream = flacenc::encode_with_fixed_block_size(
        &config,
        source,
        config.block_sizes[0],
    ).map_err(|e| ...)?;

    let mut sink = ByteSink::new();
    flac_stream.write(&mut sink)?;
    Ok(sink.as_slice().to_vec())
}
```

**API Request Update**:
```rust
let part = reqwest::blocking::multipart::Part::bytes(wav_bytes.to_vec())
    .file_name("audio.flac")
    .mime_str("audio/flac")?;
```

### Direction 3: Simplified Audio Enhancement

**Expected Gain**: 5-15ms + code simplification

**Original Pipeline** (4 steps):
1. Highpass filter (80Hz) - ✅ Keep
2. RMS normalization (-18dB target) - Initially removed, then restored
3. Soft limiting (threshold 0.7) - ❌ Removed
4. Peak normalization (0.95 target) - ❌ Removed

**Problem Discovered**: After removing RMS normalization, quiet speech recognition degraded significantly. RMS normalization is critical for Whisper because:
- Whisper's log-mel spectrogram expects consistent volume levels
- Quiet speech falls below effective detection threshold
- Normalization brings all speech into optimal recognition range

**Final Pipeline** (2 steps):
```rust
fn enhance_audio(samples: &[f32], sample_rate: u32) -> Result<Vec<f32>, CoreError> {
    // Step 1: Highpass filter for low-frequency noise
    apply_highpass_filter(&mut output, sample_rate, HIGHPASS_FREQ_HZ);

    // Step 2: RMS normalization for consistent volume
    // Critical for whisper recognition - too quiet = poor accuracy
    let rms = calculate_rms(&output);
    if rms > 1e-6 {
        let target_rms = 10f32.powf(TARGET_RMS_DB / 20.0);
        let gain = (target_rms / rms).min(10.0); // Cap at 10x to prevent extreme amplification
        apply_gain(&mut output, gain);
    }

    Ok(output)
}
```

**Note**: Added 10x gain cap to prevent extreme amplification in edge cases (e.g., pure silence/noise).

## Backward Compatibility

For CLI diagnostics and debugging, preserved WAV output:

```rust
// For production (FLAC)
pub fn stop_recording() -> Result<WavData, CoreError> {
    // ... returns FLAC bytes
}

// For CLI diagnostics (WAV)
pub fn stop_recording_wav() -> Result<WavData, CoreError> {
    // ... returns WAV bytes
}
```

## Verification

### Build Verification
```bash
cargo build -p diy_typeless_core --release
cargo build -p diy_typeless_cli --release
```

### Functional Tests
```bash
# Audio recording
./target/release/diy_typeless_cli diagnose audio --duration-seconds 3 --output ./test.wav

# Transcription with FLAC
./target/release/diy_typeless_cli transcribe ./test.wav --groq-key $GROQ_API_KEY

# Full pipeline
./target/release/diy_typeless_cli full --duration-seconds 5 --groq-key $GROQ_API_KEY
```

### Expected Results
- TLS handshake eliminated on subsequent requests
- Upload size reduced by ~50-70%
- Quiet speech recognition maintained
- User-reported "significantly faster" perceived performance

## Files Modified

| File | Changes |
|------|---------|
| `core/src/http_client.rs` | New - Global HTTP client with connection pooling |
| `core/src/transcribe.rs` | Use global client, FLAC MIME type |
| `core/src/polish.rs` | Use global client |
| `core/src/lib.rs` | Export warmup functions, add stop_recording_wav |
| `core/src/audio.rs` | FLAC encoding, simplified enhancement, dual output |
| `core/src/config.rs` | Restore TARGET_RMS_DB |
| `core/Cargo.toml` | Add flacenc dependency |
| `cli/src/commands/diagnose.rs` | Use stop_recording_wav |
| `app/DIYTypeless/State/RecordingState.swift` | TLS warmup on key down |

## Commit History

```
2703773 fix(audio): restore RMS normalization for quiet speech
330eca0 chore(ffi): regenerate bindings for new functions
3015e87 feat(audio): simplify enhancement and add FLAC encoding
82bae9e feat(http): add connection pooling and TLS warmup
```

## Lessons Learned

1. **Test edge cases early**: The quiet speech regression was caught during real-world usage. Include whisper tests in future optimization.

2. **Measure before/after**: Use `diagnose pipeline` command to quantify latency improvements.

3. **Keep escape hatches**: The `stop_recording_wav()` function proved valuable for debugging audio issues.

4. **FFI regeneration**: Remember to regenerate UniFFI bindings (`uniffi-bindgen generate`) when adding new exported functions.

## Future Optimizations

1. **Parallel Processing**: Start TLS warmup + audio encoding simultaneously
2. **Adaptive Compression**: Use lighter compression for short audio (faster encoding)
3. **Connection Health Check**: Periodically verify pooled connections aren't stale
4. **Metrics Collection**: Add latency metrics to verify optimizations in production

## References

- [flacenc crate documentation](https://docs.rs/flacenc/0.3.1/flacenc/)
- [reqwest connection pooling](https://docs.rs/reqwest/latest/reqwest/struct.ClientBuilder.html)
- Groq API Audio Transcription: https://console.groq.com/docs/speech-to-text

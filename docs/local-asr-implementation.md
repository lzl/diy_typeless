# Local ASR Implementation Memorandum

This document records the implementation details of the local Automatic Speech Recognition (ASR) feature, including both standard transcription and real-time streaming transcription. This serves as a technical reference for potential future re-implementation.

**Status**: The local ASR feature has been removed from active use due to user experience issues documented in the "Reasons for Removal" section.

---

## 1. Model Selection

### Qwen3-ASR

We selected **Qwen3-ASR** from Alibaba's Qwen team as our local ASR solution.

**Repository**: https://github.com/QwenLM/Qwen3-ASR

**Two model variants were supported**:

| Variant | Size | Primary File | Use Case |
|---------|------|--------------|----------|
| Qwen3-ASR-0.6B | ~1.9 GB | `model.safetensors` (single file) | Mobile/fast inference |
| Qwen3-ASR-1.7B | ~4.7 GB | `model-00001-of-00002.safetensors` + `model-00002-of-00002.safetensors` | Higher accuracy |

**Note**: The 0.6B model was the primary choice for desktop use due to its balance of size and performance.

### Model File Structure

A complete model directory contains:

```
qwen3-asr-0.6b/
├── config.json                 # Model configuration (~6KB)
├── model.safetensors          # Model weights in BF16 (~1.88GB)
├── tokenizer_config.json      # Tokenizer settings (~13KB)
├── vocab.json                 # Vocabulary (~2.8MB)
├── merges.txt                 # BPE merge rules (~1.7MB)
├── preprocessor_config.json   # Audio preprocessing (~330B)
└── chat_template.json         # Chat template (~1.2KB)
```

### Model Architecture

**Components**:
- **Audio Encoder (AuT)**: Conv2D downsampling + Transformer encoder
- **LLM Decoder (Qwen3)**: Standard Qwen3 Transformer with Q/K norm and MRoPE
- **Projector**: Connects encoder output to decoder input

**Processing Pipeline**:
```
WAV Audio → 16kHz Resampling → Mel Spectrogram → Conv2D (8× downsampling)
    → Transformer Encoder → Projector → Qwen3 Decoder → Text Tokens
```

---

## 2. Implementation Architecture

The implementation consists of two layers:

### 2.1 C Library Layer (`core/libs/qwen-asr/`)

A pure C inference engine with no Python dependencies.

**Core Files**:
- `qwen_asr.c` (84KB) - Main API and streaming logic
- `qwen_asr_encoder.c` (15KB) - Audio encoder implementation
- `qwen_asr_decoder.c` (19KB) - LLM decoder implementation
- `qwen_asr_audio.c` (22KB) - Audio preprocessing (Mel spectrogram)
- `qwen_asr_kernels.c` (41KB) - Compute kernels and BLAS operations
- `qwen_asr_kernels_neon.c` (12KB) - ARM NEON optimizations
- `qwen_asr_kernels_avx.c` (24KB) - x86 AVX optimizations
- `qwen_asr_tokenizer.c` - BPE tokenizer
- `qwen_asr_safetensors.c` - SafeTensors format parser

**Key Features**:
- Zero-copy architecture using `mmap()` for model loading
- Cross-platform BLAS: macOS Accelerate framework, Linux OpenBLAS
- SIMD optimizations: NEON for ARM64, AVX for x86_64
- Memory-efficient BF16 weight format

### 2.2 Rust Layer (`core/src/`)

**Files**:
- `streaming_asr.rs` - Streaming ASR implementation
- `qwen_asr_ffi.rs` - FFI bindings to C library
- `transcribe.rs` - Local ASR initialization and management
- `lib.rs` - UniFFI interface exposing to Swift

---

## 3. Streaming ASR Implementation

### 3.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    StreamingHandle                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐          ┌──────────────────┐            │
│  │ Audio Thread │ ───────► │ Inference Thread │            │
│  │  (cpal)      │          │  (C library)     │            │
│  └──────────────┘          └──────────────────┘            │
│         │                            │                      │
│         ▼                            ▼                      │
│  ┌─────────────────────────────────────────┐               │
│  │       QwenLiveAudio (Shared Buffer)    │               │
│  │  - samples: *mut c_float               │               │
│  │  - sample_offset: i64                  │               │
│  │  - mutex/cond: pthread synchronization │               │
│  └─────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Key Data Structure

```rust
// From qwen_asr_ffi.rs
pub struct QwenLiveAudio {
    pub samples: *mut c_float,      // Audio sample buffer
    pub sample_offset: i64,         // Global sample offset
    pub n_samples: i64,             // Current sample count
    pub capacity: i64,              // Buffer capacity (30 sec @ 16kHz initial)
    pub eof: c_int,                 // End-of-file flag
    pub mutex: *mut c_void,         // pthread_mutex_t
    pub cond: *mut c_void,          // pthread_cond_t
    pub thread: u64,                // Thread ID
}
```

### 3.3 Audio Capture Thread

**Location**: `streaming_asr.rs::capture_audio_live()`

**Process**:
1. Use `cpal` crate to access default input device
2. Configure for 16kHz sample rate (Qwen3-ASR requirement)
3. Real-time resampling if device doesn't support 16kHz
4. Mix multiple channels to mono
5. Write to `QwenLiveAudio` buffer with mutex protection
6. Dynamic buffer expansion for long recordings

### 3.4 Inference Thread

**Location**: `streaming_asr.rs::run_live_inference()`

**Process**:
1. Wait for initial audio (minimum 0.5 seconds)
2. Call C library function `qwen_transcribe_stream_live()`
3. Receive tokens via callback function
4. Accumulate text results
5. Return final transcript

### 3.5 Streaming Algorithm (C Layer)

**Parameters**:
```c
stream_chunk_sec = 2.0;        // Process 2-second chunks
stream_rollback = 5;           // Rollback 5 tokens for stability
stream_unfixed_chunks = 2;     // First 2 chunks have no text prefix
stream_max_new_tokens = 32;    // Max 32 new tokens per chunk
enc_window_infer = 800;        // 8-second encoder window (800 frames)
```

**Optimizations**:
- **Encoder Window Caching**: 8-second attention window avoids recomputing
- **Decoder KV Cache Reuse**: Reuses previously computed KV cache
- **Incremental Output**: Returns text via callback as it's generated

---

## 4. CLI Integration

### 4.1 Commands

**Record with real-time transcription**:
```bash
diy-typeless record --local-asr <MODEL_DIR_PATH>
```

**Full pipeline (record + transcribe + polish)**:
```bash
diy-typeless full --local-asr <MODEL_DIR_PATH> [--duration-seconds 10]
```

### 4.2 Implementation Flow

**Location**: `cli/src/main.rs::run_local_asr_recording()`

```rust
// 1. Initialize local ASR
init_local_asr(model_dir_str)?;

// 2. Start streaming session
let session_id = start_streaming_session(model_dir_str, language)?;

// 3. Record for specified duration (or until user stops)
sleep(Duration::from_secs(duration));

// 4. Stop session and get text
let text = stop_streaming_session(session_id)?;

// 5. Save to file
fs::write(&txt_path, &text)?;
```

### 4.3 FFI Interface

**Location**: `core/src/lib.rs`

**Key functions exposed via UniFFI**:
```rust
fn start_streaming_session(model_dir: String, language: Option<String>) -> Result<u64>;
fn stop_streaming_session(session_id: u64) -> Result<String>;
fn get_streaming_text(session_id: u64) -> Result<String>;
```

---

## 5. Model Download

### 5.1 Download Script

**Location**: `core/libs/qwen-asr/download_model.sh`

**Usage**:
```bash
# Interactive download
./download_model.sh

# Specify model variant
./download_model.sh --model small   # 0.6B
./download_model.sh --model large   # 1.7B

# Specify output directory
./download_model.sh --model small --dir ./my-model
```

**Sources**:
- HuggingFace: `https://huggingface.co/Qwen/Qwen3-ASR-0.6B`
- ModelScope: Mirror for mainland China

### 5.2 macOS App Integration

**Location**: `LocalAsrManager.swift` (in macOS app)

**Features**:
- `URLSessionDownloadTask` for downloading
- Resume support and progress tracking
- Storage: `~/Library/Application Support/DIYTypeless/qwen3-asr-0.6b/`
- Auto-load: Calls `initLocalAsr()` after download completes

---

## 6. Build Configuration

### 6.1 Build Script

**Location**: `core/build.rs`

**C Source Files**:
```rust
let src_files = [
    "qwen_asr.c", "qwen_asr_kernels.c", "qwen_asr_kernels_generic.c",
    "qwen_asr_kernels_neon.c", "qwen_asr_kernels_avx.c",
    "qwen_asr_audio.c", "qwen_asr_encoder.c", "qwen_asr_decoder.c",
    "qwen_asr_tokenizer.c", "qwen_asr_safetensors.c",
];
```

### 6.2 Platform-Specific Configuration

**macOS**:
```rust
build.define("USE_BLAS", None);
println!("cargo:rustc-link-lib=framework=Accelerate");
```

**Linux**:
```rust
build.define("USE_OPENBLAS", None);
println!("cargo:rustc-link-lib=openblas");
```

### 6.3 Compiler Flags

```
-O3 -march=native -ffast-math
```

---

## 7. Reasons for Removal

After extensive testing, the local ASR feature was removed from active use due to the following user experience issues:

### 7.1 Large Initial Download

**Issue**: First-time users must download a ~1.9 GB model file (for 0.6B variant).

**Impact**: Significant wait time before the feature can be used, creating a poor first impression.

**Note**: The 1.7B variant requires ~4.7 GB, which is even more prohibitive.

### 7.2 High Memory Usage

**Issue**: The model consumes approximately **1 GB of RAM** during operation.

**Impact**: Unacceptable memory footprint for a background productivity tool, especially on systems with limited RAM.

### 7.3 Poor Transcription Quality (Critical)

**Issue**: The streaming ASR produces **unacceptable quality output**:
- Frequent **repetitions** of words or phrases
- **Omissions** of spoken content
- Inconsistent results especially for real-time streaming

**Impact**: The poor transcription quality significantly degrades the subsequent Polish step, as the text optimization cannot compensate for missing or duplicated content. This makes the entire pipeline unreliable.

**Specific Problem with Streaming**: The chunk-based processing with token rollback occasionally produces incoherent text at chunk boundaries.

---

## 8. Performance Metrics (Reference)

From official documentation (`MODEL_CARD_OFFICIAL.md`):

### Qwen3-ASR-0.6B
- Time to first token: ~92ms (average)
- Real-time factor (RTF): 0.064 @ 128 concurrent
- Throughput: ~2000 seconds of audio per second (at scale)

### Recognition Accuracy (LibriSpeech)
- 0.6B: WER 2.11 (clean) | 4.55 (other)
- 1.7B: WER 1.63 (clean) | 3.38 (other)

### Language Support
- 30 languages
- 22 Chinese dialects

---

## 9. Key Design Decisions

1. **C Language Core**: Pure C implementation for the inference engine, no Python dependency
2. **BF16 Weights**: Decoder uses BF16 format to save memory while maintaining precision
3. **Zero-Copy Architecture**: Uses `mmap()` for SafeTensors loading
4. **Cross-Platform BLAS**: Accelerate on macOS, OpenBLAS on Linux
5. **Thread Safety**: `pthread_mutex`/`condvar` in C, `Arc<AtomicBool>` in Rust
6. **Streaming Optimizations**: Encoder window caching + decoder KV cache reuse

---

## 10. File Locations Summary

| Component | Path |
|-----------|------|
| C Library | `core/libs/qwen-asr/` |
| Rust Streaming | `core/src/streaming_asr.rs` |
| Rust FFI | `core/src/qwen_asr_ffi.rs` |
| Rust Transcribe | `core/src/transcribe.rs` |
| Rust Lib | `core/src/lib.rs` |
| CLI Main | `cli/src/main.rs` |
| Download Script | `core/libs/qwen-asr/download_model.sh` |
| Build Script | `core/build.rs` |

---

## 11. Lessons Learned

1. **Model Size vs. Quality Trade-off**: Even the smaller 0.6B model (~1.9GB) was too large for a smooth user experience, and its quality was not sufficient for production use.

2. **Streaming ASR Complexity**: Real-time streaming adds significant complexity (chunking, rollback, caching) that can introduce quality issues at boundaries.

3. **Memory Pressure**: ~1GB RAM usage is substantial for a macOS menu bar app and affects overall system performance.

4. **Cloud ASR Alternative**: Consider cloud-based ASR APIs (OpenAI Whisper, etc.) for better quality, though this trades privacy for accuracy.

---

*Document created: 2026-02-21*
*Last updated: 2026-02-21*

use std::env;
use std::path::PathBuf;

fn main() {
    let qwen_asr_dir = PathBuf::from("libs/qwen-asr");

    // C source file list
    let src_files = [
        "qwen_asr.c",
        "qwen_asr_kernels.c",
        "qwen_asr_kernels_generic.c",
        "qwen_asr_kernels_neon.c",
        "qwen_asr_kernels_avx.c",
        "qwen_asr_audio.c",
        "qwen_asr_encoder.c",
        "qwen_asr_decoder.c",
        "qwen_asr_tokenizer.c",
        "qwen_asr_safetensors.c",
    ];

    // Compile C code using cc crate
    let mut build = cc::Build::new();

    for file in &src_files {
        build.file(qwen_asr_dir.join(file));
    }

    // Add header file search path
    build.include(&qwen_asr_dir);

    // Compiler options
    build.flag_if_supported("-O3");
    build.flag_if_supported("-march=native");
    build.flag_if_supported("-ffast-math");
    build.flag_if_supported("-Wall");
    build.flag_if_supported("-Wextra");

    // macOS: Use Accelerate framework
    #[cfg(target_os = "macos")]
    {
        build.define("USE_BLAS", None);
        build.define("ACCELERATE_NEW_LAPACK", None);
        println!("cargo:rustc-link-lib=framework=Accelerate");
    }

    // Linux: Use OpenBLAS
    #[cfg(target_os = "linux")]
    {
        build.define("USE_BLAS", None);
        build.define("USE_OPENBLAS", None);
        build.include("/usr/include/openblas");
        println!("cargo:rustc-link-lib=openblas");
    }

    // Link math and thread libraries
    println!("cargo:rustc-link-lib=m");
    println!("cargo:rustc-link-lib=pthread");

    build.compile("qwen_asr");

    // Recompilation conditions
    for file in &src_files {
        println!("cargo:rerun-if-changed={}", qwen_asr_dir.join(file).display());
    }
    println!("cargo:rerun-if-changed={}", qwen_asr_dir.join("Makefile").display());
}

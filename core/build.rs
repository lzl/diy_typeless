use std::env;
use std::path::PathBuf;

fn main() {
    let qwen_asr_dir = PathBuf::from("libs/qwen-asr");

    // C 源文件列表
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

    // 使用 cc crate 编译 C 代码
    let mut build = cc::Build::new();

    for file in &src_files {
        build.file(qwen_asr_dir.join(file));
    }

    // 添加头文件搜索路径
    build.include(&qwen_asr_dir);

    // 编译选项
    build.flag_if_supported("-O3");
    build.flag_if_supported("-march=native");
    build.flag_if_supported("-ffast-math");
    build.flag_if_supported("-Wall");
    build.flag_if_supported("-Wextra");

    // macOS: 使用 Accelerate 框架
    #[cfg(target_os = "macos")]
    {
        build.define("USE_BLAS", None);
        build.define("ACCELERATE_NEW_LAPACK", None);
        println!("cargo:rustc-link-lib=framework=Accelerate");
    }

    // Linux: 使用 OpenBLAS
    #[cfg(target_os = "linux")]
    {
        build.define("USE_BLAS", None);
        build.define("USE_OPENBLAS", None);
        build.include("/usr/include/openblas");
        println!("cargo:rustc-link-lib=openblas");
    }

    // 链接数学库和线程库
    println!("cargo:rustc-link-lib=m");
    println!("cargo:rustc-link-lib=pthread");

    build.compile("qwen_asr");

    // 重新编译条件
    for file in &src_files {
        println!("cargo:rerun-if-changed={}", qwen_asr_dir.join(file).display());
    }
    println!("cargo:rerun-if-changed={}", qwen_asr_dir.join("Makefile").display());
}

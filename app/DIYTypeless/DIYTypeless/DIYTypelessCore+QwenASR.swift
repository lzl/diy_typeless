// Extension for Qwen3-ASR Local Support
// swiftlint:disable all
import Foundation

// MARK: - AsrProvider Enum

public enum AsrProvider: Int32 {
    case groq = 0
    case local = 1
}

// MARK: - FfiConverter for AsrProvider

public struct FfiConverterTypeAsrProvider: FfiConverter {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> AsrProvider {
        let variant: Int32 = try readInt(&buf)
        guard let provider = AsrProvider(rawValue: variant) else {
            throw UniffiInternalError.unexpectedEnumCase
        }
        return provider
    }

    public static func write(_ value: AsrProvider, into buf: inout [UInt8]) {
        writeInt(&buf, value.rawValue)
    }

    public static func lift(_ value: Int32) throws -> AsrProvider {
        guard let provider = AsrProvider(rawValue: value) else {
            throw UniffiInternalError.unexpectedEnumCase
        }
        return provider
    }

    public static func lower(_ value: AsrProvider) -> Int32 {
        return value.rawValue
    }
}

// MARK: - New Functions

public func initLocalAsr(modelDir: String) throws {
    try rustCallWithError(FfiConverterTypeCoreError_lift) {
        uniffi_diy_typeless_core_fn_func_init_local_asr(
            FfiConverterString.lower(modelDir), $0
        )
    }
}

public func isLocalAsrAvailable() -> Bool {
    return try! FfiConverterBool.lift(
        rustCall {
            uniffi_diy_typeless_core_fn_func_is_local_asr_available($0)
        }
    )
}

public func processWavBytesWithProvider(
    provider: AsrProvider,
    groqApiKey: String?,
    geminiApiKey: String,
    wavBytes: Data,
    language: String?,
    context: String?
) throws -> PipelineResult {
    return try FfiConverterTypePipelineResult.lift(
        rustCallWithError(FfiConverterTypeCoreError_lift) {
            uniffi_diy_typeless_core_fn_func_process_wav_bytes_with_provider(
                FfiConverterTypeAsrProvider.lower(provider),
                FfiConverterOptionString.lower(groqApiKey),
                FfiConverterString.lower(geminiApiKey),
                FfiConverterData.lower(wavBytes),
                FfiConverterOptionString.lower(language),
                FfiConverterOptionString.lower(context), $0
            )
        }
    )
}

// MARK: - FFI Function Declarations (C bindings)

@_silgen_name("uniffi_diy_typeless_core_fn_func_init_local_asr")
private func uniffi_diy_typeless_core_fn_func_init_local_asr(
    _ modelDir: RustBuffer,
    _ out_status: UnsafeMutablePointer<RustCallStatus>
) -> RustBuffer

@_silgen_name("uniffi_diy_typeless_core_fn_func_is_local_asr_available")
private func uniffi_diy_typeless_core_fn_func_is_local_asr_available(
    _ out_status: UnsafeMutablePointer<RustCallStatus>
) -> Int8

@_silgen_name("uniffi_diy_typeless_core_fn_func_process_wav_bytes_with_provider")
private func uniffi_diy_typeless_core_fn_func_process_wav_bytes_with_provider(
    _ provider: Int32,
    _ groqApiKey: RustBuffer,
    _ geminiApiKey: RustBuffer,
    _ wavBytes: RustBuffer,
    _ language: RustBuffer,
    _ context: RustBuffer,
    _ out_status: UnsafeMutablePointer<RustCallStatus>
) -> RustBuffer

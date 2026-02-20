import Combine
import Foundation

/// Manages local Qwen3-ASR model download and loading
@MainActor
class LocalAsrManager: ObservableObject {
    static let shared = LocalAsrManager()

    @Published var isModelAvailable = false
    @Published var isModelLoaded = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadError: String?

    private let modelDirName = "qwen3-asr-0.6b"
    private let hfRepo = "Qwen/Qwen3-ASR-0.6B"
    private var hasInitialized = false

    /// Model storage directory (~/Library/Application Support/DIYTypeless/qwen3-asr-0.6b/)
    var modelDirectory: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("DIYTypeless").appendingPathComponent(modelDirName)
    }

    /// List of model files to download (Qwen3-ASR-0.6B uses GPT-2 style tokenizer)
    private var modelFiles: [(name: String, size: Int64)] {
        [
            ("config.json", 6_000),
            ("model.safetensors", 1_880_000_000),
            ("tokenizer_config.json", 13_000),
            ("vocab.json", 2_800_000),
            ("merges.txt", 1_700_000),
            ("preprocessor_config.json", 330),
            ("chat_template.json", 1_200),
        ]
    }

    /// Check if model is already downloaded
    func checkModelAvailability() {
        guard let modelDir = modelDirectory else {
            isModelAvailable = false
            return
        }

        // Check if key files exist (model weights + config + tokenizer)
        let configFile = modelDir.appendingPathComponent("config.json")
        let modelFile = modelDir.appendingPathComponent("model.safetensors")
        let vocabFile = modelDir.appendingPathComponent("vocab.json")
        let tokenizerConfigFile = modelDir.appendingPathComponent("tokenizer_config.json")

        isModelAvailable = FileManager.default.fileExists(atPath: configFile.path)
            && FileManager.default.fileExists(atPath: modelFile.path)
            && FileManager.default.fileExists(atPath: vocabFile.path)
            && FileManager.default.fileExists(atPath: tokenizerConfigFile.path)
    }

    /// Download model files
    func downloadModel() async {
        guard !isDownloading else { return }
        guard let modelDir = modelDirectory else {
            downloadError = "Cannot access application directory"
            return
        }

        isDownloading = true
        downloadError = nil
        downloadProgress = 0

        do {
            // Create directory
            print("[LocalASR] Model directory: \(modelDir.path)")
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // Download files one by one
            let totalFiles = modelFiles.count
            var downloadedBytes: Int64 = 0
            let totalBytes = modelFiles.map { $0.size }.reduce(0, +)

            for (index, fileInfo) in modelFiles.enumerated() {
                let filename = fileInfo.name
                let url = URL(string: "https://huggingface.co/\(hfRepo)/resolve/main/\(filename)")!
                let destination = modelDir.appendingPathComponent(filename)

                // Skip if file exists and has reasonable size
                if let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 1000 {
                    downloadedBytes += fileSize
                    await MainActor.run {
                        downloadProgress = Double(downloadedBytes) / Double(totalBytes)
                    }
                    continue
                }

                // Download file
                print("[LocalASR] Downloading: \(url)")
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LocalAsrError.downloadFailed("\(filename): Invalid response")
                }

                guard httpResponse.statusCode == 200 else {
                    // Read response body for error details
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("[LocalASR] HTTP \(httpResponse.statusCode) for \(filename): \(body.prefix(200))")
                    throw LocalAsrError.downloadFailed("\(filename): HTTP \(httpResponse.statusCode)")
                }

                try data.write(to: destination)
                downloadedBytes += Int64(data.count)

                await MainActor.run {
                    downloadProgress = Double(downloadedBytes) / Double(totalBytes)
                }
            }

            await MainActor.run {
                isDownloading = false
                isModelAvailable = true
                downloadProgress = 1.0
            }

            // Auto-load model after download completes
            try? await initialize()

        } catch {
            await MainActor.run {
                isDownloading = false
                downloadError = error.localizedDescription
                print("[LocalASR] Download failed: \(error)")
            }
        }
    }

    /// Initialize local ASR (load model into memory)
    func initialize() async throws {
        guard !hasInitialized else { return }
        guard isModelAvailable else {
            throw LocalAsrError.modelNotFound
        }
        guard let modelDir = modelDirectory else {
            throw LocalAsrError.modelNotFound
        }

        // Call Rust FFI initialization
        try await Task.detached {
            try initLocalAsr(modelDir: modelDir.path)
        }.value

        hasInitialized = true
        await MainActor.run {
            isModelLoaded = true
        }
    }

    /// Get total model size (for display)
    var totalModelSize: String {
        let totalBytes = modelFiles.map { $0.size }.reduce(0, +)
        let gb = Double(totalBytes) / 1_000_000_000
        return String(format: "%.1fGB", gb)
    }
}

enum LocalAsrError: Error, LocalizedError {
    case modelNotFound
    case downloadFailed(String)
    case initializationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Local model not found"
        case .downloadFailed(let msg):
            return "Download failed: \(msg)"
        case .initializationFailed(let msg):
            return "Model initialization failed: \(msg)"
        }
    }
}

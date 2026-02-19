import Combine
import Foundation

/// 管理本地 Qwen3-ASR 模型下载和加载
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

    /// 模型存储目录 (~/Library/Application Support/DIYTypeless/qwen3-asr-0.6b/)
    var modelDirectory: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("DIYTypeless").appendingPathComponent(modelDirName)
    }

    /// 需要下载的模型文件列表
    private var modelFiles: [(name: String, size: Int64)] {
        [
            ("config.json", 2_000),
            ("model.safetensors", 1_200_000_000),
            ("tokenizer.json", 2_000_000),
            ("tokenizer_config.json", 5_000),
            ("preprocessor_config.json", 2_000),
        ]
    }

    /// 检查模型是否已下载
    func checkModelAvailability() {
        guard let modelDir = modelDirectory else {
            isModelAvailable = false
            return
        }

        // 检查关键文件是否存在
        let configFile = modelDir.appendingPathComponent("config.json")
        let modelFile = modelDir.appendingPathComponent("model.safetensors")

        isModelAvailable = FileManager.default.fileExists(atPath: configFile.path)
            && FileManager.default.fileExists(atPath: modelFile.path)
    }

    /// 下载模型文件
    func downloadModel() async {
        guard !isDownloading else { return }
        guard let modelDir = modelDirectory else {
            downloadError = "无法访问应用目录"
            return
        }

        isDownloading = true
        downloadError = nil
        downloadProgress = 0

        do {
            // 创建目录
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // 逐个下载文件
            let totalFiles = modelFiles.count
            var downloadedBytes: Int64 = 0
            let totalBytes = modelFiles.map { $0.size }.reduce(0, +)

            for (index, fileInfo) in modelFiles.enumerated() {
                let filename = fileInfo.name
                let url = URL(string: "https://huggingface.co/\(hfRepo)/resolve/main/\(filename)")!
                let destination = modelDir.appendingPathComponent(filename)

                // 如果文件已存在且大小合理，跳过
                if let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 1000 {
                    downloadedBytes += fileSize
                    await MainActor.run {
                        downloadProgress = Double(downloadedBytes) / Double(totalBytes)
                    }
                    continue
                }

                // 下载文件
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw LocalAsrError.downloadFailed("无法下载 \(filename)")
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

        } catch {
            await MainActor.run {
                isDownloading = false
                downloadError = error.localizedDescription
            }
        }
    }

    /// 初始化本地 ASR（加载模型到内存）
    func initialize() async throws {
        guard !hasInitialized else { return }
        guard isModelAvailable else {
            throw LocalAsrError.modelNotFound
        }
        guard let modelDir = modelDirectory else {
            throw LocalAsrError.modelNotFound
        }

        // 调用 Rust FFI 初始化
        try await Task.detached {
            try initLocalAsr(modelDir: modelDir.path)
        }.value

        hasInitialized = true
        await MainActor.run {
            isModelLoaded = true
        }
    }

    /// 获取模型总大小（用于显示）
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
            return "本地模型未找到"
        case .downloadFailed(let msg):
            return "下载失败: \(msg)"
        case .initializationFailed(let msg):
            return "模型初始化失败: \(msg)"
        }
    }
}

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

    private var currentFileIndex = 0
    private var downloadedBytes: Int64 = 0
    private var totalBytes: Int64 = 0

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
        currentFileIndex = 0
        downloadedBytes = 0
        totalBytes = modelFiles.map { $0.size }.reduce(0, +)

        do {
            // Create directory
            print("[LocalASR] Model directory: \(modelDir.path)")
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // Download files one by one
            for (index, fileInfo) in modelFiles.enumerated() {
                currentFileIndex = index
                let filename = fileInfo.name
                let url = URL(string: "https://huggingface.co/\(hfRepo)/resolve/main/\(filename)")!
                let destination = modelDir.appendingPathComponent(filename)

                // Skip if file exists and has reasonable size
                if let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 1000 {
                    downloadedBytes += fileSize
                    downloadProgress = Double(downloadedBytes) / Double(totalBytes)
                    continue
                }

                // Download file with progress tracking
                print("[LocalASR] Downloading: \(url)")
                try await downloadFile(from: url, to: destination)
            }

            isDownloading = false
            isModelAvailable = true
            downloadProgress = 1.0

            // Auto-load model after download completes
            try? await initialize()

        } catch {
            isDownloading = false
            downloadError = error.localizedDescription
            print("[LocalASR] Download failed: \(error)")
        }
    }

    /// Download a single file using URLSessionDownloadTask with progress
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let downloader = FileDownloader(url: url, destination: destination)
        downloader.onProgress = { [weak self] bytesWritten in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.downloadedBytes += bytesWritten
                self.downloadProgress = Double(self.downloadedBytes) / Double(self.totalBytes)
            }
        }
        try await downloader.download()
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
        isModelLoaded = true
    }

    /// Get total model size (for display)
    var totalModelSize: String {
        let totalBytes = modelFiles.map { $0.size }.reduce(0, +)
        let gb = Double(totalBytes) / 1_000_000_000
        return String(format: "%.1fGB", gb)
    }
}

// MARK: - File Downloader

/// Handles single file download with progress tracking
@MainActor
class FileDownloader: NSObject, URLSessionDownloadDelegate {
    let url: URL
    let destination: URL

    var onProgress: ((Int64) -> Void)?
    var continuation: CheckedContinuation<Void, Error>?
    var lastReportedTotalBytes: Int64 = 0

    init(url: URL, destination: URL) {
        self.url = url
        self.destination = destination
    }

    func download() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let delta = bytesWritten
        if delta > 0 {
            onProgress?(delta)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        session.finishTasksAndInvalidate()

        guard let response = downloadTask.response as? HTTPURLResponse else {
            continuation?.resume(throwing: LocalAsrError.downloadFailed("Invalid response"))
            continuation = nil
            return
        }

        guard response.statusCode == 200 else {
            continuation?.resume(throwing: LocalAsrError.downloadFailed("HTTP \(response.statusCode)"))
            continuation = nil
            return
        }

        do {
            // Move downloaded file to destination
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume()
            continuation = nil
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            session.invalidateAndCancel()
            continuation?.resume(throwing: error)
            continuation = nil
        }
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

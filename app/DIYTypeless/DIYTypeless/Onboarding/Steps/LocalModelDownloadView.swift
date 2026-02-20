import SwiftUI

struct LocalModelDownloadView: View {
    @ObservedObject var state: OnboardingState
    @StateObject private var localManager = LocalAsrManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Download Local Model")
                    .font(.system(size: 24, weight: .semibold))

                Text("Qwen3-ASR runs entirely on your device")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                if !localManager.isModelAvailable {
                    // Model needs to be downloaded
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.orange)
                            Text("Model files need to be downloaded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }

                        Text("\(localManager.totalModelSize), works offline after download, no internet required")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)

                        if localManager.isDownloading {
                            VStack(spacing: 8) {
                                ProgressView(value: localManager.downloadProgress)
                                    .progressViewStyle(.linear)

                                Text("Downloading... \(Int(localManager.downloadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: {
                                Task { await localManager.downloadModel() }
                            }) {
                                Label("Download Model", systemImage: "icloud.and.arrow.down")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        if let error = localManager.downloadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                } else if !localManager.isModelLoaded {
                    // Model downloaded, auto-loading
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Model downloaded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }

                        HStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                            Text("Loading model into memory...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .onAppear {
                        Task { await loadModel() }
                    }
                } else {
                    // Model is loaded and ready
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Model ready to use")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            localManager.checkModelAvailability()
        }
    }

    private func loadModel() async {
        do {
            try await localManager.initialize()
        } catch {
            // Error is displayed via localManager's published properties
        }
    }
}

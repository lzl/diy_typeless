import SwiftUI

struct AsrProviderSelectionStepView: View {
    @ObservedObject var state: OnboardingState
    @StateObject private var localManager = LocalAsrManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("语音识别方式")
                    .font(.system(size: 24, weight: .semibold))

                Text("选择适合你的语音识别引擎")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                providerCard(
                    provider: .groq,
                    isSelected: state.asrProvider == .groq
                ) {
                    state.asrProvider = .groq
                }

                providerCard(
                    provider: .local,
                    isSelected: state.asrProvider == .local
                ) {
                    state.asrProvider = .local
                }
            }
            .frame(maxWidth: 360)

            // 本地 ASR 下载/加载 UI
            if state.asrProvider == .local {
                localAsrSetupView
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            localManager.checkModelAvailability()
        }
    }

    private func providerCard(provider: AsrProvider, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: provider == .groq ? "cloud.fill" : "cpu.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(provider.description)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var localAsrSetupView: some View {
        VStack(spacing: 16) {
            if !localManager.isModelAvailable {
                // 需要下载模型
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                        Text("需要下载模型文件")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }

                    Text("约 \(localManager.totalModelSize)，下载后完全离线使用，无需网络连接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    if localManager.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: localManager.downloadProgress)
                                .progressViewStyle(.linear)

                            Text("下载中... \(Int(localManager.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            Task { await localManager.downloadModel() }
                        }) {
                            Label("下载模型", systemImage: "icloud.and.arrow.down")
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
                // 模型已下载，需要加载
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("模型已下载")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }

                    Button(action: {
                        Task { await loadModel() }
                    }) {
                        if localManager.isModelLoaded == false && localManager.isModelAvailable {
                            Label("加载模型", systemImage: "play.circle.fill")
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(localManager.isModelLoaded)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                // 模型已加载
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("模型已就绪，可以开始使用")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func loadModel() async {
        do {
            try await localManager.initialize()
        } catch {
            // 错误会通过 localManager 的 published 属性显示
        }
    }
}

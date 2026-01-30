import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showKeys = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                permissionsSection
                apiKeysSection
                usageSection
                statusSection
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DIY Typeless")
                .font(.largeTitle.bold())
            Text("Hold the Right Option key to record, release to get polished text.")
                .foregroundColor(.secondary)
        }
    }

    private var permissionsSection: some View {
        GroupBox(label: Text("Permissions").font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    isGranted: viewModel.permissionStatus.accessibility,
                    actionTitle: "Open Settings",
                    action: viewModel.openAccessibilitySettings
                )
                PermissionRow(
                    title: "Input Monitoring",
                    isGranted: viewModel.permissionStatus.inputMonitoring,
                    actionTitle: "Open Settings",
                    action: viewModel.openInputMonitoringSettings
                )
                PermissionRow(
                    title: "Microphone",
                    isGranted: viewModel.permissionStatus.microphone,
                    actionTitle: "Open Settings",
                    action: viewModel.openMicrophoneSettings
                )
                HStack {
                    Button("Request Permissions") {
                        viewModel.requestPermissions()
                    }
                    Button("Refresh Status") {
                        viewModel.refreshPermissions()
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var apiKeysSection: some View {
        GroupBox(label: Text("API Keys").font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                if showKeys {
                    TextField("Groq API Key", text: $viewModel.groqApiKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Gemini API Key", text: $viewModel.geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Groq API Key", text: $viewModel.groqApiKey)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Gemini API Key", text: $viewModel.geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button(showKeys ? "Hide Keys" : "Show Keys") {
                        showKeys.toggle()
                    }
                    Button("Save Keys") {
                        viewModel.saveApiKeys()
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var usageSection: some View {
        GroupBox(label: Text("How to Use").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Grant Accessibility, Input Monitoring, and Microphone permissions.")
                Text("2. Save your Groq and Gemini API keys.")
                Text("3. Hold the Right Option key to speak, release to finish.")
                Text("4. Text is pasted into the focused field or copied to clipboard.")
            }
            .padding(.top, 6)
        }
    }

    private var statusSection: some View {
        GroupBox(label: Text("Status").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("State: \(viewModel.status.rawValue)")
                Text(viewModel.statusMessage)
                    .foregroundColor(.secondary)
                if !viewModel.lastOutput.isEmpty {
                    Text("Last Output:")
                        .font(.subheadline.bold())
                    Text(viewModel.lastOutput)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(6)
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isGranted ? .green : .orange)
            Text(title)
            Spacer()
            Button(actionTitle, action: action)
        }
    }
}


import SwiftUI
import DIYTypelessCore

struct GeminiKeyStepView: View {
    @Bindable var state: OnboardingState

    private var selectedProvider: Binding<ApiProvider> {
        Binding(
            get: { state.selectedLLMProvider },
            set: { state.selectLLMProvider($0) }
        )
    }

    private var activeKey: Binding<String> {
        switch state.selectedLLMProvider {
        case .gemini:
            return $state.geminiKey
        case .openai:
            return $state.openAIKey
        case .groq:
            return $state.geminiKey
        }
    }

    private var activeKeyValue: String {
        switch state.selectedLLMProvider {
        case .gemini:
            return state.geminiKey
        case .openai:
            return state.openAIKey
        case .groq:
            return state.geminiKey
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "LLM Provider",
            subtitle: "Choose where polishing and text commands should run."
        ) {
            OnboardingIconBadge(systemName: "sparkles")
        } content: {
            OnboardingSurfaceCard(alignment: .leading, padding: 16) {
                VStack(spacing: 14) {
                    providerSelector

                    ProviderConsoleLink {
                        state.openProviderConsole(for: state.selectedLLMProvider)
                    }

                    SecureField(state.selectedLLMProvider.apiKeyPlaceholder, text: activeKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appSurfaceSubtle)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.appBorderSubtle.opacity(0.7), lineWidth: 1)
                        )

                    HStack(spacing: 12) {
                        Button("Validate") {
                            state.validateActiveLLMKey()
                        }
                        .buttonStyle(EnhancedSecondaryButtonStyle())
                        .disabled(state.activeLLMValidation == .validating || activeKeyValue.isEmpty)

                        ValidationStatusView(state: state.activeLLMValidation)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var providerSelector: some View {
        HStack(spacing: 12) {
            ForEach(state.llmProviderOptions, id: \.self) { provider in
                Button {
                    selectedProvider.wrappedValue = provider
                } label: {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(provider == state.selectedLLMProvider ? Color.appSurface : Color.appSurfaceSubtle)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                provider == state.selectedLLMProvider
                                    ? Color.brandPrimary
                                    : Color.appBorderSubtle.opacity(0.7),
                                lineWidth: provider == state.selectedLLMProvider ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

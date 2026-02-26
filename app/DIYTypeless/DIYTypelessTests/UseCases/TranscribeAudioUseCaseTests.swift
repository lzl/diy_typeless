//
//  TranscribeAudioUseCaseTests.swift
//  DIYTypelessTests
//
//  Tests for TranscribeAudioUseCase
//

import Testing
import Foundation
@testable import DIYTypeless

@MainActor
@Suite("TranscribeAudioUseCase Tests")
struct TranscribeAudioUseCaseTests {

    // MARK: - Empty Audio Tests

    @Test("Empty audio throws TranscriptionError.emptyAudio")
    func testEmptyAudio_ThrowsError() async throws {
        // Given: Use case with empty audio data
        let useCase = TranscribeAudioUseCaseImpl()
        let emptyAudio = AudioData(bytes: Data(), durationSeconds: 0.0)

        // When/Then: Should throw emptyAudio error
        await #expect(throws: TranscriptionError.emptyAudio) {
            try await useCase.execute(audioData: emptyAudio, apiKey: "test-key", language: nil)
        }
    }

    @Test("Empty Data throws TranscriptionError.emptyAudio")
    func testEmptyData_ThrowsError() async throws {
        // Given: Use case with empty Data
        let useCase = TranscribeAudioUseCaseImpl()
        let emptyAudio = AudioData(bytes: Data([]), durationSeconds: 0.0)

        // When/Then: Should throw emptyAudio error
        await #expect(throws: TranscriptionError.emptyAudio) {
            try await useCase.execute(audioData: emptyAudio, apiKey: "test-key", language: nil)
        }
    }

    // MARK: - Non-Empty Audio Validation

    @Test("Non-empty audio passes validation (no emptyAudio error)")
    func testNonEmptyAudio_PassesValidation() async throws {
        // Given: Use case with valid audio data
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01, 0x02]), durationSeconds: 0.1)

        // When: Call with non-empty audio
        // Then: Should NOT throw emptyAudio error (FFI may fail but validation passes)
        do {
            _ = try await useCase.execute(audioData: audioData, apiKey: "test-key", language: nil)
        } catch {
            // FFI error is expected, but emptyAudio should NOT be thrown
            if case TranscriptionError.emptyAudio = error {
                Issue.record("Should not throw emptyAudio for non-empty audio")
            }
            // Other errors are acceptable (FFI needs real API key)
        }
    }

    // MARK: - Language Parameter

    @Test("Language parameter is optional and passes validation")
    func testLanguageParameter_PassesValidation() async throws {
        // Given: Use case with language hint
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01]), durationSeconds: 0.05)

        // When: Call with language hint
        // Then: Should not throw emptyAudio
        do {
            _ = try await useCase.execute(
                audioData: audioData,
                apiKey: "test-key",
                language: "en"
            )
        } catch {
            if case TranscriptionError.emptyAudio = error {
                Issue.record("Should handle language parameter")
            }
        }
    }

    @Test("Chinese language hint is supported")
    func testChineseLanguage_PassesValidation() async throws {
        // Given: Use case with Chinese language hint
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01]), durationSeconds: 0.05)

        // When: Call with Chinese language
        // Then: Should not throw emptyAudio
        do {
            _ = try await useCase.execute(
                audioData: audioData,
                apiKey: "test-key",
                language: "zh"
            )
        } catch {
            if case TranscriptionError.emptyAudio = error {
                Issue.record("Should handle Chinese language hint")
            }
        }
    }
}
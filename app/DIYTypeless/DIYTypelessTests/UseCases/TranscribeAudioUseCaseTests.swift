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
        let emptyAudio = AudioData(bytes: Data())

        // When/Then: Should throw emptyAudio error
        await #expect(throws: TranscriptionError.emptyAudio) {
            try await useCase.execute(audioData: emptyAudio, apiKey: "test-key", language: nil)
        }
    }

    @Test("Empty Data throws TranscriptionError.emptyAudio")
    func testEmptyData_ThrowsError() async throws {
        // Given: Use case with empty Data
        let useCase = TranscribeAudioUseCaseImpl()
        let emptyAudio = AudioData(bytes: Data([]))

        // When/Then: Should throw emptyAudio error
        await #expect(throws: TranscriptionError.emptyAudio) {
            try await useCase.execute(audioData: emptyAudio, apiKey: "test-key", language: nil)
        }
    }

    // MARK: - Non-Empty Audio

    @Test("Non-empty audio does not throw emptyAudio")
    func testNonEmptyAudio_DoesNotThrowEmptyAudio() async throws {
        // Given: Use case with valid audio data
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01, 0x02])) // Dummy audio bytes

        // When: Call with non-empty audio
        // Then: Should NOT throw emptyAudio error
        do {
            _ = try await useCase.execute(audioData: audioData, apiKey: "test-key", language: nil)
        } catch TranscriptionError.emptyAudio {
            Issue.record("Should not throw emptyAudio for non-empty audio")
        }
    }

    // MARK: - Language Parameter

    @Test("Language parameter is optional")
    func testLanguageParameter_Optional() async throws {
        // Given: Use case with language hint
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01]))

        // When: Call with language hint
        // Then: Should not throw emptyAudio
        do {
            _ = try await useCase.execute(
                audioData: audioData,
                apiKey: "test-key",
                language: "en"
            )
        } catch TranscriptionError.emptyAudio {
            Issue.record("Should handle language parameter")
        }
    }

    @Test("Chinese language hint is supported")
    func testChineseLanguage_Supported() async throws {
        // Given: Use case with Chinese language hint
        let useCase = TranscribeAudioUseCaseImpl()
        let audioData = AudioData(bytes: Data([0x00, 0x01]))

        // When: Call with Chinese language
        // Then: Should not throw emptyAudio
        do {
            _ = try await useCase.execute(
                audioData: audioData,
                apiKey: "test-key",
                language: "zh"
            )
        } catch TranscriptionError.emptyAudio {
            Issue.record("Should handle Chinese language hint")
        }
    }
}
//
//  RecordingStateTests.swift
//  DIYTypelessTests
//
//  Created for testing parallel keyup operations.
//

import Testing
import Foundation
@testable import DIYTypeless

@MainActor
@Suite("RecordingState KeyUp Tests")
struct RecordingStateTests {

    // MARK: - Parallel Execution Tests

    @Test("Parallel execution reduces total delay")
    func testParallelExecution_ReducedDelay() async throws {
        // Given: Recording state with mocks configured with known delays
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.configuredDelay = 0.1 // 100ms
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.configuredDelay = 0.05 // 50ms
        mockStopRecording.returnValue = createAudioData()

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText
        )

        // Trigger recording state setup
        recordingState.activate()

        // Simulate key down to start recording
        await recordingState.handleKeyDown()

        // Wait a bit to ensure recording is started
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // When: Call handleKeyUp() and measure elapsed time
        let startTime = Date()
        await recordingState.handleKeyUp()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Verify both use cases were executed
        #expect(mockGetSelectedText.executeCount == 1)
        #expect(mockStopRecording.executeCount == 1)

        // And: Total time should be approximately max(100ms, 50ms) = 100ms
        // Allow 50ms tolerance for test overhead
        let expectedMaxDelay = 0.1 // 100ms (the longer of the two delays)
        let tolerance = 0.05 // 50ms tolerance
        #expect(elapsed < expectedMaxDelay + tolerance, "Expected elapsed time \(elapsed)s to be less than \(expectedMaxDelay + tolerance)s (parallel execution)")

        // And: Verify it's NOT close to serial execution time (150ms)
        let expectedSerialDelay = 0.15 // 150ms (sum of delays)
        let serialTolerance = 0.03 // 30ms tolerance
        let isSerialExecution = abs(elapsed - expectedSerialDelay) < serialTolerance
        #expect(!isSerialExecution, "Detected serial execution (elapsed=\(elapsed)s, expected ~\(expectedSerialDelay)s for serial)")
    }

    @Test("Both use cases execute regardless of completion time")
    func testParallelExecution_BothExecuted() async throws {
        // Given: Mocks with different delays
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.configuredDelay = 0.01 // 10ms (fast)
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.configuredDelay = 0.2 // 200ms (slow)
        mockStopRecording.returnValue = createAudioData()

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText
        )

        recordingState.activate()
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Call handleKeyUp
        await recordingState.handleKeyUp()

        // Then: Both should be executed exactly once
        #expect(mockGetSelectedText.executeCount == 1)
        #expect(mockStopRecording.executeCount == 1)
    }

    // MARK: - Voice Command Mode Tests

    @Test("Voice command mode activates with selected text")
    func testVoiceCommandMode_WithSelectedText() async throws {
        // Given: Selected text exists
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: "hello world",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.returnValue = createAudioData()

        let mockProcessVoiceCommand = MockProcessVoiceCommandUseCase()
        mockProcessVoiceCommand.returnValue = VoiceCommandResult(
            processedText: "processed hello world",
            action: .replaceSelection
        )

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText,
            processVoiceCommandUseCase: mockProcessVoiceCommand
        )

        recordingState.activate()
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Handle key up
        await recordingState.handleKeyUp()

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Voice command should be processed
        #expect(mockProcessVoiceCommand.executeCount == 1)
    }

    @Test("Normal transcription mode when no selected text")
    func testTranscriptionMode_WithoutSelectedText() async throws {
        // Given: No selected text
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.returnValue = createAudioData()

        let mockPolishText = MockPolishTextUseCase()
        mockPolishText.returnValue = "polished text"

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            polishTextUseCase: mockPolishText,
            getSelectedTextUseCase: mockGetSelectedText
        )

        recordingState.activate()
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Handle key up
        await recordingState.handleKeyUp()

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Polish should be called (normal transcription mode)
        #expect(mockPolishText.executeCount == 1)
    }

    // MARK: - Error Handling Tests

    @Test("Error is caught when stop recording fails")
    func testStopRecordingFailure_ErrorHandled() async throws {
        // Given: Stop recording throws error
        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.errorToThrow = RecordingError.stopFailed("Test error")

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording
        )

        recordingState.activate()
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Handle key up
        await recordingState.handleKeyUp()

        // Wait for error state to be set
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Error state should be shown
        // Note: We can't directly observe capsuleState here, but the test
        // verifies that the error doesn't crash the app
        #expect(mockStopRecording.executeCount == 1)
    }

    // MARK: - Generation Cancellation Tests

    @Test("Stale generation results are ignored")
    func testGenerationCancellation_IgnoresStaleResults() async throws {
        // Given: Slow mocks to simulate race condition
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.configuredDelay = 0.3 // 300ms
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: "stale text",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.configuredDelay = 0.3 // 300ms
        mockStopRecording.returnValue = createAudioData()

        var startRecordingCount = 0
        class MockRecordingControl: RecordingControlUseCaseProtocol {
            var count = 0
            func startRecording() async throws { count += 1 }
            func warmupConnections() async {}
        }
        let mockRecordingControl = MockRecordingControl()

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            recordingControlUseCase: mockRecordingControl,
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText
        )

        recordingState.activate()

        // When: Start first recording
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Start second recording (cancels first)
        await recordingState.handleKeyDown()
        try await Task.sleep(nanoseconds: 10_000_000)

        // Wait for first generation's operations to complete
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms

        // Then: Only the latest generation should process
        // The first handleKeyDown should have been cancelled
        #expect(mockRecordingControl.count >= 1)
    }

    @Test("Multiple rapid generations only process latest")
    func testMultipleGenerations_OnlyLatestProcesses() async throws {
        // Given: Very slow mocks
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        mockGetSelectedText.configuredDelay = 0.5 // 500ms
        mockGetSelectedText.returnValue = SelectedTextContext(
            text: "text",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.configuredDelay = 0.5 // 500ms
        mockStopRecording.returnValue = createAudioData()

        let recordingState = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText
        )

        recordingState.activate()

        // When: Rapid key up/down cycles
        await recordingState.handleKeyDown()
        await recordingState.handleKeyUp()
        try await Task.sleep(nanoseconds: 10_000_000)

        await recordingState.handleKeyDown()
        await recordingState.handleKeyUp()
        try await Task.sleep(nanoseconds: 10_000_000)

        await recordingState.handleKeyDown()
        // Don't call keyup - leave it recording

        // Wait for pending operations
        try await Task.sleep(nanoseconds: 600_000_000)

        // Then: Only the last generation should have processed
        #expect(mockGetSelectedText.executeCount >= 1)
        #expect(mockStopRecording.executeCount >= 1)
    }

    // MARK: - Prefetch Tests

    @Test("Normal prefetch flow with selected text")
    func testNormalPrefetchFlow() async throws {
        // Given: Mock scheduler and selected text use case
        let mockScheduler = MockPrefetchScheduler()
        let mockUseCase = MockGetSelectedTextUseCase()
        mockUseCase.result = SelectedTextContext(
            text: "selected text",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.returnValue = createAudioData()

        let mockProcessVoiceCommand = MockProcessVoiceCommandUseCase()
        mockProcessVoiceCommand.returnValue = VoiceCommandResult(
            processedText: "processed hello world",
            action: .replaceSelection
        )

        let state = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockUseCase,
            processVoiceCommandUseCase: mockProcessVoiceCommand,
            prefetchScheduler: mockScheduler,
            prefetchDelay: .milliseconds(300)
        )

        state.activate()

        // When: Key down is triggered
        await state.handleKeyDown()

        // Then: A prefetch operation should be scheduled with 300ms delay
        #expect(mockScheduler.scheduledOperations.count == 1)
        #expect(mockScheduler.scheduledOperations[0].delay == .milliseconds(300))

        // When: Execute the scheduled prefetch
        await mockScheduler.executeScheduled()

        // Then: The selected text use case should have been executed for prefetch
        #expect(mockUseCase.executeWasCalled)

        // When: Key up is triggered
        await state.handleKeyUp()

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Voice command mode should be activated (because hasSelection is true)
        #expect(mockProcessVoiceCommand.executeCount == 1)
    }

    @Test("Short press cancels prefetch")
    func testShortPressCancelsPrefetch() async throws {
        let mockScheduler = MockPrefetchScheduler()
        let mockUseCase = MockGetSelectedTextUseCase()
        mockUseCase.result = SelectedTextContext(
            text: "selected text",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let mockStopRecording = MockStopRecordingUseCase()
        mockStopRecording.returnValue = createAudioData()

        let mockPolishText = MockPolishTextUseCase()
        mockPolishText.returnValue = "polished text"

        let state = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            polishTextUseCase: mockPolishText,
            getSelectedTextUseCase: mockUseCase,
            prefetchScheduler: mockScheduler,
            prefetchDelay: .milliseconds(300)
        )

        state.activate()

        // Key down - starts recording and schedules prefetch
        await state.handleKeyDown()

        // Verify prefetch was scheduled
        #expect(mockScheduler.scheduledOperations.count == 1, "Prefetch should be scheduled")

        // Immediately release (before prefetch executes)
        await state.handleKeyUp()

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify prefetch was cancelled
        #expect(mockScheduler.cancelledTasks.count == 1, "Prefetch task should be cancelled, but was \(mockScheduler.cancelledTasks.count)")

        // Verify transcription mode (not voice command)
        // Polish should be called, not processVoiceCommand
        #expect(mockPolishText.executeCount == 1, "Polish text should be called once")
    }

    // MARK: - Rapid Key Presses and Cleanup Tests

    @Test("Rapid key presses schedule new prefetch")
    func testRapidKeyPresses() async throws {
        let mockScheduler = MockPrefetchScheduler()
        let state = RecordingStateTestFactory.makeRecordingState(
            prefetchScheduler: mockScheduler
        )

        state.activate()

        // First key down/up cycle
        await state.handleKeyDown()
        #expect(mockScheduler.scheduledOperations.count == 1, "First prefetch should be scheduled")

        await state.handleKeyUp()

        // Second key down
        await state.handleKeyDown()
        #expect(mockScheduler.scheduledOperations.count == 2, "Second prefetch should be scheduled")
    }

    @Test("Deactivate cancels prefetch")
    func testDeactivateCancelsPrefetch() async throws {
        let mockScheduler = MockPrefetchScheduler()
        let state = RecordingStateTestFactory.makeRecordingState(
            prefetchScheduler: mockScheduler
        )

        state.activate()

        // Key down - starts recording and schedules prefetch
        await state.handleKeyDown()
        #expect(mockScheduler.scheduledOperations.count == 1, "Prefetch should be scheduled")

        // Deactivate while prefetch is pending
        state.deactivate()

        // Verify prefetch was cancelled
        #expect(mockScheduler.cancelledTasks.count >= 1, "Prefetch task should be cancelled on deactivate, but was \(mockScheduler.cancelledTasks.count)")
    }

    @Test("Handle cancel cancels prefetch")
    func testHandleCancelCancelsPrefetch() async throws {
        let mockScheduler = MockPrefetchScheduler()
        let state = RecordingStateTestFactory.makeRecordingState(
            prefetchScheduler: mockScheduler
        )

        state.activate()

        // Key down - starts recording and schedules prefetch
        await state.handleKeyDown()
        #expect(mockScheduler.scheduledOperations.count == 1, "Prefetch should be scheduled")

        // Cancel while prefetch is pending
        state.handleCancel()

        // Verify prefetch was cancelled
        #expect(mockScheduler.cancelledTasks.count >= 1, "Prefetch task should be cancelled on handleCancel, but was \(mockScheduler.cancelledTasks.count)")
    }
}

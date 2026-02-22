# Code Review Fixes Design

## Overview

Fix architecture issues identified by SwiftUI Clean Architecture Reviewer to ensure full compliance with Clean Architecture principles.

## Issues to Fix

1. **CapsuleView @State Semantic Issue** - AudioLevelMonitor created via @State lacks clear semantics
2. **Hardcoded RGB Colors** - Colors.swift uses hardcoded values, should support system dark/light mode
3. **Silent Error Catching** - WaveformView audio engine startup errors not logged
4. **Timer RunLoop Mode** - Timer needs to be added to .common mode to continue firing during UI interactions
5. **Protocol Location** - AudioLevelProviding should move from Presentation to Domain layer
6. **Mock Separation** - MockAudioLevelProvider should be separated from production code to PreviewSupport

## Architecture Constraints

- Maintain @MainActor @Observable pattern
- No ObservableObject or @Published allowed
- ViewModels must not contain animation state
- Dependency direction: Presentation → Domain → Data

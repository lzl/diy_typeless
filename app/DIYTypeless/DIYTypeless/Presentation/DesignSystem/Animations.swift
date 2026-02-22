import SwiftUI

// MARK: - Animation Constants
// Pure presentation layer - animation curves and timing

enum AppAnimation {
    /// Micro-interactions (button presses, small state changes)
    static let micro = Animation.easeOut(duration: 0.15)

    /// State changes (capsule state transitions)
    static let stateChange = Animation.easeInOut(duration: 0.25)

    /// Page transitions (onboarding step changes)
    static let pageTransition = Animation.spring(
        response: 0.35,
        dampingFraction: 0.8,
        blendDuration: 0.3
    )

    /// Modal presentation animations
    static let modalPresentation = Animation.spring(
        response: 0.4,
        dampingFraction: 0.7
    )

    /// Breathing animation for recording state
    static func breathing(duration: Double = 2.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    /// Pulse animation for indicators
    static func pulse(duration: Double = 1.5) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    /// Shimmer effect for loading states
    static func shimmer(duration: Double = 1.5) -> Animation {
        .linear(duration: duration).repeatForever(autoreverses: false)
    }

    /// Waveform bar animation
    static let waveformBar = Animation.linear(duration: 0.05)

    /// Progress bar fill animation
    static let progressFill = Animation.easeInOut(duration: 0.3)

    /// Shake animation for errors
    static let shake = Animation.spring(response: 0.1, dampingFraction: 0.2)
}

// MARK: - Animation Duration Constants
extension Double {
    /// Micro-interaction duration (150ms)
    static let animationMicro: Double = 0.15

    /// Standard state change duration (250ms)
    static let animationStandard: Double = 0.25

    /// Page transition duration (350ms)
    static let animationPage: Double = 0.35

    /// Breathing cycle duration (2000ms)
    static let animationBreathing: Double = 2.0
}

// MARK: - View Modifiers for Common Animations

/// Breathing scale effect for recording state
struct BreathingEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let intensity: CGFloat
    let duration: Double

    init(intensity: CGFloat = 0.02, duration: Double = 2.0) {
        self.intensity = intensity
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + phase * intensity)
            .opacity(1.0 - phase * intensity * 0.2)
            .animation(AppAnimation.breathing(duration: duration), value: phase)
            .onAppear { phase = 1 }
            .onDisappear { phase = 0 }
    }
}

/// Pulsing glow effect
struct PulsingGlowEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let color: Color
    let radius: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(0.3 + phase * 0.3),
                radius: radius + phase * 5,
                x: 0,
                y: 0
            )
            .animation(AppAnimation.pulse(duration: duration), value: phase)
            .onAppear { phase = 1 }
    }
}

/// Shimmer loading effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            )
            .animation(AppAnimation.shimmer(), value: phase)
            .onAppear { phase = 1 }
    }
}

/// Shake effect for error feedback
struct ShakeEffect: ViewModifier {
    @State private var shakeCount: Int = 0
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: sin(Double(shakeCount)) * intensity)
            .onAppear {
                for i in 0..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                        shakeCount = i
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a breathing animation effect
    func breathing(intensity: CGFloat = 0.02, duration: Double = 2.0) -> some View {
        modifier(BreathingEffect(intensity: intensity, duration: duration))
    }

    /// Applies a pulsing glow effect
    func pulsingGlow(color: Color = .brandPrimary, radius: CGFloat = 10, duration: Double = 1.5) -> some View {
        modifier(PulsingGlowEffect(color: color, radius: radius, duration: duration))
    }

    /// Applies a shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }

    /// Applies a shake effect for errors
    func shake(intensity: CGFloat = 5) -> some View {
        modifier(ShakeEffect(intensity: intensity))
    }
}

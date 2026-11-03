import Foundation

/// Turns high-frequency trackpad wheel deltas into deliberate zoom steps.
/// Discrete mouse-wheel events remain responsive (one notch = one step).
/// Pure Swift so its behavior is deterministic and testable without AppKit.
public struct ScrollStepAccumulator: Sendable {
    private var remainder = 0.0
    public init() {}

    public mutating func consume(delta: Double, precise: Bool) -> Int {
        guard delta.isFinite, delta != 0 else { return 0 }
        if !precise {
            remainder = 0
            return delta > 0 ? 1 : -1
        }
        // Small touchpad events should not produce one zoom level apiece.
        // Clamp massive event spikes (e.g. coming out of sleep).
        remainder = max(-48, min(48, remainder + delta))
        let steps = max(-4, min(4, Int(remainder / 9.0)))
        remainder -= Double(steps) * 9.0
        return steps
    }

    public mutating func reset() { remainder = 0 }
}

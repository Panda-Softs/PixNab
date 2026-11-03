import Foundation

/// One in-flight UI delivery at a time. The caller must call finish() only once
/// after the work really completes (not merely after scheduling it).
public final class FrameAdmissionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = false

    public init() {}

    public func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    public func finish() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}

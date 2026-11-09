import Foundation
import Vision

/// Cancels active Vision requests as well as preventing subsequent recognition work.
public final class AnalysisCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var requests: [ObjectIdentifier: VNRequest] = [:]

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        let active = Array(requests.values)
        lock.unlock()
        active.forEach { $0.cancel() }
    }

    func register(_ request: VNRequest) throws {
        lock.lock()
        let allowed = !cancelled
        if allowed { requests[ObjectIdentifier(request)] = request }
        lock.unlock()
        guard allowed else { request.cancel(); throw CancellationError() }
    }

    func unregister(_ request: VNRequest) {
        lock.lock()
        requests.removeValue(forKey: ObjectIdentifier(request))
        lock.unlock()
    }
}

public enum AnalysisWork {
    @TaskLocal public static var cancellation: AnalysisCancellation?
}

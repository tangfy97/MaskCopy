import Vision
import XCTest
@testable import MaskeCore

private final class CancellationProbe: VNRequest {
    var cancellations = 0
    override func cancel() { cancellations += 1; super.cancel() }
}

final class CancellationTests: XCTestCase {
    func testCancellationReachesActiveRequestAndRejectsSubsequentWork() throws {
        let token = AnalysisCancellation()
        let active = CancellationProbe()
        try token.register(active)
        token.cancel()
        XCTAssertEqual(active.cancellations, 1)
        token.unregister(active)
        let pending = CancellationProbe()
        XCTAssertThrowsError(try token.register(pending)) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(pending.cancellations, 1)
    }

    func testFinishedRequestIsNotCancelledWithANewerRequest() throws {
        let token = AnalysisCancellation()
        let done = CancellationProbe(), active = CancellationProbe()
        try token.register(done)
        token.unregister(done)
        try token.register(active)
        token.cancel()
        XCTAssertEqual(done.cancellations, 0)
        XCTAssertEqual(active.cancellations, 1)
    }
}

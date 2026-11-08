import XCTest
import os
@testable import Maske

private actor ImportGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class SessionTests: XCTestCase {
    private func image(width: Int = 400) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: max(2, width / 2), bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        return try XCTUnwrap(context.makeImage())
    }

    func testCancelledReadCannotReplaceANewerDocument() async throws {
        let started = expectation(description: "Old read started")
        let finished = expectation(description: "Old read finished")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let session = Session { image in
            if image.width == 2 {
                started.fulfill()
                release.wait()
                finished.fulfill()
            }
            return (image, nil)
        }
        session.start(with: [try image(width: 2)])
        await fulfillment(of: [started], timeout: 2)
        session.start(with: [try image(width: 4)])
        for _ in 0..<100 where session.analyzing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(session.pages.first?.image.width, 4)
        release.signal()
        await fulfillment(of: [finished], timeout: 2)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(session.pages.first?.image.width, 4)
        session.finish()
    }

    func testCancelledImportCannotReopenTheSession() async throws {
        let started = expectation(description: "Import started")
        let gate = ImportGate()
        defer { Task { await gate.release() } }
        let source = try image()
        let session = Session { ($0, nil) }
        session.importImages {
            started.fulfill()
            await gate.wait()
            return [source]
        }
        await fulfillment(of: [started], timeout: 2)
        session.finish()
        await gate.release()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(session.pages.isEmpty)
        XCTAssertTrue(session.path.isEmpty)
        XCTAssertFalse(session.analyzing)
        XCTAssertNil(session.previewImage)
    }

    func testMaskEditsInvalidateThePreviewRevision() throws {
        var page = Session.Page(image: try image(), kind: .passport, country: nil,
                                findings: [Finding(kind: .photo, rect: CGRect(x: 0, y: 0, width: 0.3, height: 0.5))])
        let revision = page.revision
        page.findings[0].isOn = false
        XCTAssertNotEqual(page.revision, revision)
    }

    func testPreviewStaysInMemoryAndExportsOwnTheirFiles() throws {
        Exporter.clear()
        defer { Exporter.clear() }
        let page = Session.Page(image: try image(), kind: .passport, country: nil, findings: [])
        let preview = try XCTUnwrap(Exporter.preview([page], recipient: "Test Hotel", purpose: "Check-in"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Exporter.directory.path))
        let first = try XCTUnwrap(Exporter.writeCopy(preview, recipient: "Test Hotel"))
        let second = try XCTUnwrap(Exporter.writeCopy(preview, recipient: "Test Hotel"))
        XCTAssertNotEqual(first, second)
        Exporter.discard(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testNextSessionRemovesAnAbandonedTemporaryCopy() throws {
        let file = try XCTUnwrap(Exporter.writeCopy(try image(), recipient: "Test Hotel"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        _ = Session()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testCopiesAreRenderedOffMainAndReusedUntilInputsChange() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let session = Session(render: { pages, _ in
            XCTAssertFalse(Thread.isMainThread)
            calls.withLock { $0 += 1 }
            return pages.first?.image
        })
        session.pages = [Session.Page(image: try image(), kind: .passport, country: nil,
                                     findings: [Finding(kind: .photo, rect: CGRect(x: 0, y: 0, width: 0.3, height: 0.5))])]
        let first = await session.prepareCopy(recipient: "Hotel Nord", purpose: "Check-in")
        XCTAssertTrue(first)
        let repeated = await session.prepareCopy(recipient: " Hotel Nord ", purpose: "Check-in")
        XCTAssertTrue(repeated)
        XCTAssertEqual(calls.withLock { $0 }, 1)
        let changed = await session.prepareCopy(recipient: "Hotel Nord", purpose: "Reservation")
        XCTAssertTrue(changed)
        XCTAssertEqual(calls.withLock { $0 }, 2)
        session.pages[0].findings[0].isOn = false
        XCTAssertNil(session.copy)
        let edited = await session.prepareCopy(recipient: "Hotel Nord", purpose: "Reservation")
        XCTAssertTrue(edited)
        XCTAssertEqual(calls.withLock { $0 }, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: Exporter.directory.path))
        session.finish()
    }

    func testFinishingDuringRenderingCannotPublishACopy() async throws {
        let started = expectation(description: "Copy rendering started")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let session = Session(render: { pages, _ in
            started.fulfill()
            release.wait()
            return pages.first?.image
        })
        session.pages = [Session.Page(image: try image(), kind: .passport, country: nil, findings: [])]
        let work = Task { await session.prepareCopy(recipient: "Test hotel", purpose: "Check-in") }
        await fulfillment(of: [started], timeout: 2)
        session.finish()
        release.signal()
        let ready = await work.value
        XCTAssertFalse(ready)
        XCTAssertNil(session.copy)
        XCTAssertTrue(session.path.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: Exporter.directory.path))
    }

    func testFourPageRenderingPerformance() throws {
        let page = Session.Page(image: try image(width: 2600), kind: .passport, country: nil,
                                findings: [Finding(kind: .photo, rect: CGRect(x: 0.05, y: 0.15, width: 0.25, height: 0.65))])
        let pages = Array(repeating: page, count: 4)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let result = Exporter.preview(pages, recipient: "Test hotel", purpose: "Check-in only")
            XCTAssertNotNil(result)
        }
    }
}

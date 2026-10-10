import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testDocumentQueuedBeforeChannelSetupIsDrainedOnce() {
    let delegate = AppDelegate()
    let url = URL(fileURLWithPath: "/tmp/dawn chorus.wav")

    XCTAssertNil(delegate.takePendingSharedFile())
    XCTAssertTrue(delegate.queueDocument(url))
    XCTAssertEqual(delegate.takePendingSharedFile(), [
      "uri": url.absoluteString,
      "name": "dawn chorus.wav",
    ])
    XCTAssertNil(delegate.takePendingSharedFile())
  }

  func testLatestDocumentReplacesPendingDocument() {
    let delegate = AppDelegate()
    delegate.queueDocument(URL(fileURLWithPath: "/tmp/first.wav"))
    let latest = URL(fileURLWithPath: "/tmp/second.wav")
    delegate.queueDocument(latest)

    XCTAssertEqual(delegate.takePendingSharedFile()?["uri"], latest.absoluteString)
    XCTAssertNil(delegate.takePendingSharedFile())
  }

  func testSameDocumentCanBeOpenedAgainAfterBeingDrained() {
    let delegate = AppDelegate()
    let url = URL(fileURLWithPath: "/tmp/dawn.wav")
    delegate.queueDocument(url)
    _ = delegate.takePendingSharedFile()

    XCTAssertTrue(delegate.queueDocument(url))
    XCTAssertEqual(delegate.takePendingSharedFile()?["uri"], url.absoluteString)
  }

  func testNonFileURLIsUnhandledAndPreservesPendingDocument() {
    let delegate = AppDelegate()
    let document = URL(fileURLWithPath: "/tmp/dawn.wav")
    delegate.queueDocument(document)

    XCTAssertFalse(delegate.queueDocument(URL(string: "https://example.com/dawn.wav")!))
    XCTAssertFalse(delegate.queueDocument(URL(string: "birdnet://example")!))
    XCTAssertEqual(delegate.takePendingSharedFile()?["uri"], document.absoluteString)
  }
}

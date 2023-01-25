@testable import Standups
import XCTest

@MainActor
class RecordMeetingTests: XCTestCase {
	
	func testTimer() async throws {
		let recordModel = RecordMeetingModel(standup: .mock)
		
		
		let expectation = self.expectation(description: "onMeetingFinished")
		recordModel.onMeetingFinished = { _ in
			expectation.fulfill()
		}
		
		await recordModel.task()
		_ = XCTWaiter.wait(for: [expectation], timeout: 0)
		
		XCTAssertEqual(recordModel.secondsElapsed, 6)
		XCTAssertEqual(recordModel.dismiss, true)
	}
}

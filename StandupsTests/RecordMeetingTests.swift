import Clocks
import Dependencies
@testable import Standups
import XCTest

@MainActor
class RecordMeetingTests: XCTestCase {
	
	func testTimer() async throws {
		
		await withDependencies {
			$0.continuousClock = ImmediateClock()
		} operation: {
			var standup = Standup.mock
			standup.duration = .seconds(6)
			let recordModel = RecordMeetingModel(
				standup: standup
			)
			let expectation = self.expectation(description: "onMeetingFinished")
			recordModel.onMeetingFinished = { _ in expectation.fulfill() }
			
			await recordModel.task()
			self.wait(for: [expectation], timeout: 0)
			XCTAssertEqual(recordModel.secondsElapsed, 6)
			XCTAssertEqual(recordModel.dismiss, true)
		}
	}
}

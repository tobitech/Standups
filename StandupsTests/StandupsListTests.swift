@testable import Standups
import XCTest

@MainActor
class StandupsListTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		try? FileManager.default.removeItem(at: .documentsDirectory.appending(component: "standups.json"))
	}
	
	func testPersistence() async throws {
		let listModel = StandupsListModel()
		
		XCTAssertEqual(listModel.standups.count, 0)
		
		listModel.addStandupButtonTapped()
		listModel.confirmAddStandupButtonTapped()
		XCTAssertEqual(listModel.standups.count, 1)
		
		try await Task.sleep(for: .milliseconds(1_100))
		
		let nextLaunchListModel = StandupsListModel()
		XCTAssertEqual(nextLaunchListModel.standups.count, 1)
	}
}

import XCTest
@testable import SharedFinanceApp

final class SharedFinanceAppTests: XCTestCase {
    func testExample() {
        let state = AppState()
        XCTAssertEqual(state.selectedTab, .projects)
    }
}

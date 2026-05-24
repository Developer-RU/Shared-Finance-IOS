import XCTest
@testable import SharedFinanceApp

final class BalanceCalculatorTests: XCTestCase {
    func testBalanceCalculation() {
        let participant = Participant(name: "Alex", contributionAmount: 100)
        let expense = Expense(projectID: UUID(), participantID: participant.id, amount: 40, categoryID: UUID(), title: "Taxi")

        let balances = BalanceCalculator.calculate(participants: [participant], expenses: [expense])

        XCTAssertEqual(balances.count, 1)
        XCTAssertEqual(balances.first?.balance, 60)
    }
}

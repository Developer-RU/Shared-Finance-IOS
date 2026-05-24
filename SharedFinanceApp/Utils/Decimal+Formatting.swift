import Foundation

extension Decimal {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        return formatter.string(from: self as NSDecimalNumber) ?? "0"
    }
}

import SwiftUI

struct ParticipantBalanceRowView: View {
    let balance: ParticipantBalance

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(balance.name)
                    .font(.body)
                Text("\(String(localized: "balance_contribution_label")) \(balance.contribution.currencyString) • \(String(localized: "balance_expense_label")) \(balance.expense.currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(balance.balance.currencyString)
                .fontWeight(.semibold)
                .foregroundStyle(balance.balance >= 0 ? .green : .red)
        }
    }
}

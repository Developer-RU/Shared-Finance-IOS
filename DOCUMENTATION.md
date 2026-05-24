# Shared-Finance-IOS Documentation

## 1. Product Purpose

Shared-Finance-IOS is an offline-first shared expense tracking app designed for groups of people who need transparent accounting without mandatory cloud infrastructure.

The product is built around **project-level accounting**. Each project is an isolated financial scope with its own participants, expenses, balances, and history.

Typical use cases:

- family household budgets;
- travel groups and vacation planning;
- roommates sharing rent and utility costs;
- small work teams tracking project expenses.

## 2. Product Principles

- **Offline-first by default**: critical flows work without internet.
- **Project isolation**: separate contexts must not leak into each other.
- **Transparent accounting**: history and balances should be traceable.
- **Selective sync control**: users sync only what they explicitly choose.

## 3. Functional Scope

### 3.1 Project Management

- Create, update, and remove projects.
- Keep multiple active projects simultaneously.
- Ensure all accounting operations are scoped to a project.

### 3.2 Participant Management

- Add and remove participants inside each project.
- Link expenses to the paying participant.
- Use participant identity in balance calculations.

### 3.3 Expense Management

- Create expenses with amount, category, title, comment, and date.
- Edit and delete existing expense records.
- Keep all records linked to both project and participant identity.

### 3.4 Balance Calculation

- Automatically calculate who owes whom within a project.
- Recalculate balances after every expense change.
- Display clear repayment-oriented summaries.

### 3.5 Change History

- Log key operations for auditability.
- Improve team trust through transparent change tracking.

### 3.6 Bluetooth Synchronization (BLE)

- Peer-to-peer sync between nearby devices.
- No mandatory cloud relay for transfer.
- JSON payload transfer for interoperability.
- Explicit selection of projects included in sync.

### 3.7 Conflict Handling

- Detect conflicts during merge operations.
- Compare local and remote versions by identity/version metadata.
- Allow deterministic and user-controlled conflict resolution.

## 4. Why Selective Project Sync Matters

Selective sync is a core functional differentiator:

- users can share only a travel project with travel participants;
- users can keep family budget data private;
- users can exchange one work project without exposing unrelated records.

This supports practical privacy and reduces over-sharing.

## 5. Technical Architecture

### 5.1 Stack

- Swift
- SwiftUI
- Combine
- MVVM
- SQLite
- CoreBluetooth

### 5.2 Module Responsibilities

- `SharedFinanceApp/Models` - domain entities and sync models.
- `SharedFinanceApp/ViewModels` - presentation-state orchestration.
- `SharedFinanceApp/Views` - screen definitions.
- `SharedFinanceApp/Components` - reusable UI blocks.
- `SharedFinanceApp/Services` - business services and domain workflows.
- `SharedFinanceApp/Database` - persistence, schema migration, DB access.
- `SharedFinanceApp/BLE` - BLE transport and synchronization protocol.

## 6. Data and Persistence

- Local SQLite storage on device.
- Migration support for schema evolution.
- Local-first behavior as a core product requirement.

## 7. Cross-Platform Synchronization Compatibility

Synchronization data contracts are designed to be interoperable across both platforms.

Supported sync scenarios:

- iOS to iOS.
- Android to Android.
- iOS to Android and Android to iOS.

Data is structured in compatible payloads and entity models to preserve consistency between platform implementations.

## 8. Build and Run

1. Install Xcode and command-line tools.
2. Install XcodeGen:
   - `brew install xcodegen`
3. Generate the project:
   - `xcodegen generate`
4. Open `SharedFinance.xcodeproj`.
5. Run from Xcode.
6. Use a physical iPhone for BLE validation.

## 9. Testing Strategy

- Unit tests for services and core logic.
- Balance-calculation tests for edge cases.
- Sync and conflict workflow validation.
- Regression checks for project isolation.

## 10. Public Repository Readiness

Repository-level publication assets:

- `README.md`
- `ARCHITECTURE.md`
- `LICENSE` (MIT)
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `PUBLISHING.md`
- `CHANGELOG.md`

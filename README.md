# Short Finance for iOS

> Free and open-source software. You can use, modify, and distribute this project under the MIT License.
>
> Companion repositories:
> - iOS: https://github.com/Developer-RU/short-finance-ios
> - Android: https://github.com/Developer-RU/short-finance-android

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform: iOS](https://img.shields.io/badge/Platform-iOS-000000)
![Cross-Platform Sync](https://img.shields.io/badge/Sync-iOS%20%E2%86%94%20Android-blue)
![Offline First](https://img.shields.io/badge/Mode-Offline--First-orange)

Offline-first iOS app for shared expense tracking between multiple participants, organized by independent projects, with selective Bluetooth synchronization.

## Table of Contents

- [Overview](#overview)
- [Who This App Is For](#who-this-app-is-for)
- [Core Features](#core-features)
- [How Project-Scoped Sync Works](#how-project-scoped-sync-works)
- [Cross-Platform Compatibility](#cross-platform-compatibility)
- [Architecture at a Glance](#architecture-at-a-glance)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Build and Test](#build-and-test)
- [Privacy and Security](#privacy-and-security)
- [Open Source and Contribution](#open-source-and-contribution)
- [Documentation](#documentation)
- [License](#license)

## Overview

Short Finance helps groups manage shared spending without requiring a cloud backend. Instead of mixing everything into one ledger, the app uses a project-first model:

- each project has its own participants;
- each project has its own expenses;
- balances are calculated per project;
- synchronization can be performed per project.

This approach is ideal when users manage multiple independent contexts in parallel.

## Who This App Is For

- Families managing household expenses.
- Friends splitting travel costs.
- Roommates tracking rent and utilities.
- Small teams tracking project operational expenses.
- Any group that needs transparent, local-first shared expense accounting.

## Core Features

- Multi-project expense tracking with strict project-level data isolation.
- Participant management inside each project.
- Expense records with amount, category, payer, title, comment, and date.
- Automatic balance calculation to show who owes whom.
- Change history for better transparency and auditability.
- Offline-first data flow with local persistence.
- BLE peer-to-peer synchronization.
- Selective synchronization of only the projects chosen by the user.
- Conflict detection and conflict resolution workflows.

## How Project-Scoped Sync Works

Unlike traditional sync models that transfer entire datasets, Short Finance allows users to transfer only selected projects.

Examples:

- Share only the "Summer Trip" project with travel participants.
- Keep personal "Family Budget" data private.
- Sync a single work project without exposing unrelated data.

This significantly improves practical privacy control and reduces unnecessary data transfer.

## Cross-Platform Compatibility

Synchronization payloads and data models are platform-compatible.

Supported synchronization scenarios:

- iOS to iOS;
- Android to Android;
- iOS to Android and Android to iOS.

This lets mixed-device teams and families operate on consistent shared project data.

## Architecture at a Glance

- UI and presentation state: MVVM with SwiftUI.
- Data storage: local SQLite.
- Device communication: CoreBluetooth.
- Domain and infrastructure logic: dedicated service layer.
- Sync merge model: identity/version-based conflict detection.

## Tech Stack

- Swift
- SwiftUI
- Combine
- MVVM
- SQLite
- CoreBluetooth (BLE)

## Project Structure

- `SharedFinanceApp/Models` - core domain models.
- `SharedFinanceApp/ViewModels` - presentation logic and screen state.
- `SharedFinanceApp/Views` - screens.
- `SharedFinanceApp/Components` - reusable UI components.
- `SharedFinanceApp/Services` - business services and orchestration.
- `SharedFinanceApp/Database` - persistence and migrations.
- `SharedFinanceApp/BLE` - Bluetooth communication and sync protocol.
- `SharedFinanceApp/Resources` - assets and localization resources.
- `SharedFinanceApp/Tests` - unit and feature tests.

## Getting Started

1. Install Xcode and Xcode Command Line Tools.
2. Install XcodeGen:
   - `brew install xcodegen`
3. Generate the Xcode project:
   - `xcodegen generate`
4. Open `SharedFinance.xcodeproj`.
5. Run on a physical iPhone for BLE testing.

## Build and Test

- Build from Xcode using the `SharedFinanceApp` scheme.
- Run tests with `SharedFinanceAppTests`.
- Optionally run `xcodebuild` in CI environments.

## Privacy and Security

- No cloud service is required for core usage.
- Data remains local by default.
- Sync is direct device-to-device over BLE.
- Users explicitly choose which projects to sync.

For security reporting guidelines, see `SECURITY.md`.

## Open Source and Contribution

- Contribution process: `CONTRIBUTING.md`
- Community rules: `CODE_OF_CONDUCT.md`
- Release process: `PUBLISHING.md`
- Change history format: `CHANGELOG.md`
- Security policy: `SECURITY.md`

## Documentation

- `DOCUMENTATION.md` - product and functional documentation.
- `ARCHITECTURE.md` - technical architecture details.
- `PUBLISHING.md` - public repository and release guidance.
- `CHANGELOG.md` - user-visible change history.

## License

Licensed under the MIT License. See `LICENSE`.

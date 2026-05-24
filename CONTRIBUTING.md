# Contributing to Shared-Finance-IOS

Thank you for your interest in improving Shared-Finance-IOS.

## Scope

This repository contains the standalone iOS implementation.
Android is maintained in a separate project.

## How to contribute

1. Fork the repository.
2. Create a feature branch from `main`.
3. Implement your change with tests where applicable.
4. Ensure the app builds and core flows run locally.
5. Open a pull request with a clear description.

## Development setup

1. Install Xcode and Xcode Command Line Tools.
2. Install XcodeGen:
   - `brew install xcodegen`
3. Generate the project:
   - `xcodegen generate`
4. Open `SharedFinance.xcodeproj` and run the app.

## Coding standards

- Follow Swift API Design Guidelines.
- Keep MVVM boundaries clear.
- Prefer small, testable services.
- Avoid introducing cloud-only assumptions; app is offline-first.
- Keep BLE sync logic project-selective and deterministic.

## Pull request checklist

- [ ] The change has a clear purpose.
- [ ] The app builds successfully.
- [ ] Existing behavior is not regressed.
- [ ] Documentation was updated if needed.
- [ ] The PR description explains user impact.

## Reporting bugs

When reporting issues, include:
- iOS version and device model.
- Reproduction steps.
- Expected vs actual behavior.
- Logs or screenshots when possible.

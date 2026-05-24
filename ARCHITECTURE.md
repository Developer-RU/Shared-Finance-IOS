# Short Finance iOS Architecture

## Overview

Short Finance iOS follows an offline-first architecture designed for shared expense tracking with project-level data isolation and selective BLE synchronization.

## Architectural style

- Presentation: SwiftUI views.
- State and orchestration: MVVM with Combine.
- Domain logic: service layer.
- Data access: SQLite via dedicated database manager and migrations.
- Device-to-device sync: BLE module with conflict handling.

## Core modules

- `SharedFinanceApp/Models`
  - Domain entities: projects, participants, expenses, history, sync models.
- `SharedFinanceApp/ViewModels`
  - UI state holders and interaction orchestrators.
- `SharedFinanceApp/Views` and `SharedFinanceApp/Components`
  - Screen composition and reusable visual blocks.
- `SharedFinanceApp/Services`
  - Balance calculation, repositories, backup, error logging, sync helpers.
- `SharedFinanceApp/Database`
  - Persistence gateway, schema migration and low-level DB behavior.
- `SharedFinanceApp/BLE`
  - BLE manager, protocol and device communication abstractions.

## Data model principles

- Every record is scoped to a project.
- Identity is stable across devices (UUID-based entities).
- Versioning and timestamps support deterministic merge decisions.
- History records improve traceability of changes.

## Sync model

- Sync is explicitly initiated by users.
- Only selected projects are included in transfer payload.
- Transport is BLE peer-to-peer without cloud mediation.
- Payloads are serialized in JSON.
- Conflicts are detected by identity/version mismatch and resolved by policy or user choice.

## Non-functional goals

- Reliability in offline mode.
- Predictable behavior under partial sync.
- Maintainable modular code boundaries.
- Testability of business logic and merge decisions.

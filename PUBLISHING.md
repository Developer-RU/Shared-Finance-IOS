# Publishing Guide (iOS Repository)

## Goal

Prepare this repository for public GitHub publication with a clear structure, legal metadata, and contributor onboarding.

## Required repository files

- `README.md`
- `DOCUMENTATION.md`
- `ARCHITECTURE.md`
- `LICENSE` (MIT)
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `CHANGELOG.md`

## Pre-publish checklist

- [ ] Confirm no private credentials are present.
- [ ] Confirm no personal or confidential data in sample datasets.
- [ ] Verify BLE and local database features compile and run.
- [ ] Ensure docs match actual behavior.
- [ ] Validate project generation via XcodeGen.
- [ ] Tag an initial public release version.

## Suggested release process

1. Create release branch.
2. Update `CHANGELOG.md`.
3. Run final smoke tests on real device.
4. Merge to `main`.
5. Create GitHub release notes.

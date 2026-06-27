# Implementation Plan: Local Runtime and Profile Management

**Branch**: `feature/time-machine-local-runtime-profile-management` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

## Summary
Retroactively specify and verify existing local Hermes profile, runtime model, raw configuration, MCP YAML, and guarded CLI/SSH command management.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation, Darwin, YAML helpers; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Local Hermes home/profile directory, Hermes CLI executable, filesystem approval policy, SSH credentials/keychain for remote hosts  
**Storage**: Local profile/config/env/SOUL/MCP YAML files; active_profile marker  
**Testing**: Xcode build plus local runtime smoke checks  
**Constraints**: Guard local writes, preserve default profile protections, remove temporary SSH key files

## Constitution Check
- **Native control surface**: Pass. Local runtime/profile management is exposed through native Configuration sections.
- **Integration contracts**: Pass. Preserves local Hermes config/profile/MCP YAML conventions.
- **Security guardrails**: Pass. Filesystem approval and SSH key cleanup are required.
- **Verification**: Pass with build plus local runtime smoke checks; no automated test target exists.
- **Maintainability**: Pass. Adds SDD artifacts only.

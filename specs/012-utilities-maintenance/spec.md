# Feature Specification: Utilities and Maintenance

**Feature Branch**: `feature/time-machine-utilities-maintenance`  
**Created**: 2026-06-27  
**Status**: Refined
**Input**: User description: "Feature: Utilities and Maintenance. Description: Provides local utilities for clipboard and prompt retention, raw stream debugging, repository updates, knowledge erasure, speech-to-text input, and reachability monitoring. Relevant files: HermesMacOS/HermesUtilitiesView.swift, HermesMacOS/HermesInstallationView.swift, HermesMacOS/HermesKnowledgeEraserUtility.swift, HermesMacOS/HermesSpeechToText.swift, HermesMacOS/HermesReachabilityMonitor.swift, docs/tutorial-getting-started.md. Focus on this feature only; do not modify other features."
**Refined**: 2026-06-28 — Knowledge eraser search no longer includes local_memory provider results and now includes Hindsight provider results.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use utility panels safely (Priority: P1)
A user opens Utilities and manages clipboard history, prompt/response history, raw stream debugging, knowledge erasure, and Hermes installation update workflows from a single native panel.

**Independent Test**: Open Utilities, expand each panel, verify safe defaults and visible status/error output without performing destructive work.

**Acceptance Scenarios**:
1. **Given** Utilities opens, **When** the user expands panels, **Then** clipboard monitoring remains off by default and utility sections show clear labels/status.
2. **Given** prompt/response history is enabled, **When** Ask or Chat entries exist, **Then** recent history is visible from the utility panel.
3. **Given** knowledge eraser is used, **When** a topic is scanned, **Then** candidates are shown for review before any erase action.
4. **Given** knowledge eraser scans Hermes memory providers, **When** Hindsight provider search returns matching memories, **Then** those Hindsight candidates are shown for review and no local_memory provider search results are included.
5. **Given** Hermes Installation is opened, **When** repository status refreshes, **Then** branch, lag, dirty state, conflicts, and operation output are visible.

---

### User Story 2 - Dictate prompts with selected STT engine (Priority: P2)
A user dictates prompt text through either Apple local Speech or Whisper WebSocket transcription and can stop/cancel safely.

**Independent Test**: Select STT engine, start dictation, stop it, and verify prompt text/status/error handling.

**Acceptance Scenarios**:
1. **Given** Apple local engine is selected and microphone permission exists, **When** recording starts, **Then** progressive local transcription appends to the prompt.
2. **Given** Whisper WebSocket is selected, **When** recording stops with transcription enabled, **Then** recorded audio is sent to the configured WebSocket and transcript appends.
3. **Given** permission, locale, audio format, or network fails, **When** dictation starts or stops, **Then** status/error messages explain the failure and recording resources are cleaned up.

---

### User Story 3 - Monitor service reachability and maintenance safety (Priority: P3)
A user sees API/dashboard reachability state and uses maintenance workflows without leaking secrets or running risky repository updates blindly.

**Independent Test**: Run reachability loops and installation refresh/preview paths against local endpoints and repo state.

**Acceptance Scenarios**:
1. **Given** API or dashboard endpoints respond with HTTP 2xx-4xx, **When** reachability probes run, **Then** the corresponding indicator becomes reachable.
2. **Given** an API key exists, **When** probes run, **Then** authorization is sent via bearer header without exposing the key in UI.
3. **Given** the Hermes Agent repository is dirty, **When** update controls render, **Then** update is disabled until the dirty state is addressed.
4. **Given** merge/update fails, **When** the review prompt is generated, **Then** it includes branch, lag, conflicts, dirty summary, and operation output for user review.

### Edge Cases
- Clipboard retention remains opt-in and can be cleared.
- Knowledge erasure requires a non-empty topic and selected candidates before erase.
- STT stop/cancel should release audio taps, cancel tasks, and clean temporary recorded audio files where applicable.
- Reachability probes tolerate localhost variants and time out quickly.
- Repository update should not run over uncommitted changes.

## Requirements *(mandatory)*
- **FR-001**: System MUST provide native Utility sections for clipboard history, messages history, stream debugging, knowledge eraser, and Hermes installation maintenance.
- **FR-002**: Clipboard monitoring MUST be opt-in and clearable.
- **FR-003**: Knowledge eraser MUST scan, select, archive, and erase through an explicit two-step review flow guarded by filesystem access policy.
- **FR-003A**: Knowledge eraser MUST exclude search results sourced from the Hermes `local_memory` memory provider.
- **FR-003B**: Knowledge eraser MUST include search results sourced from the Hermes `hindsight` memory provider when that provider returns topic matches.
- **FR-004**: Hermes installation maintenance MUST refresh repository status, preview updates, block unsafe updates over dirty state, and generate a review prompt.
- **FR-005**: Speech-to-text MUST support Apple local and Whisper WebSocket engines with recording, stop/cancel, status, and error handling.
- **FR-006**: Reachability monitor MUST probe common local API and dashboard endpoints and include API key authorization only through secure keychain retrieval.
- **FR-SEC**: System MUST avoid rendering secrets in utility output and must keep destructive/retentive behaviors opt-in or explicitly confirmed.
- **FR-INT**: System MUST preserve documented local endpoint, dashboard, tutorial, and maintenance contracts.

### Key Entities
- **HermesUtilitiesView**: Utility container and disclosure state owner.
- **HermesInstallationSession / HermesInstallationView**: Repository status, preview, update, and review prompt flow.
- **HermesKnowledgeEraserStore / HermesKnowledgeEraserUtilityPanel**: Scan/review/archive/erase knowledge cleanup flow, including Hindsight provider candidates and excluding local_memory provider search results.
- **HermesSpeechToTextSession**: STT engine selection, recording, transcription, and cleanup.
- **HermesReachabilityMonitor**: API/dashboard service probe loop.

## Success Criteria *(mandatory)*
- **SC-001**: Utilities panels render with safe default disclosure and retention behavior.
- **SC-002**: Knowledge eraser requires scan/review before erase, archives removed candidates, includes Hindsight provider matches, and excludes local_memory provider search results.
- **SC-003**: STT engines report recording/transcription/error states and clean up audio resources.
- **SC-004**: Reachability indicators reflect API/dashboard availability without exposing credentials.
- **SC-005**: Installation maintenance displays repository state and blocks unsafe updates over dirty working trees.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully.
- **SC-SMOKE**: Primary utilities/maintenance flows can be validated independently with documented smoke checks.

## Assumptions
- This pass documents the existing Utilities implementation and does not add new maintenance APIs.
- Live verification of STT/reachability/repository update requires local permissions and reachable services.
- Knowledge eraser provider-memory search now targets the Hindsight Hermes memory provider; local_memory provider search results are intentionally excluded.
- No automated test target exists yet.

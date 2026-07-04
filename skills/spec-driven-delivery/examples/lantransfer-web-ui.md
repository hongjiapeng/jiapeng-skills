# Example: LanTransfer Web Upload Page Redesign

## Requirement

Redesign the LanTransfer web upload page to be minimal, polished, Apple-like, and responsive for phone and desktop.

## Assumptions

- The upload page already exists in the LanTransfer target repository.
- The redesign is limited to the web upload page and its directly related assets.
- Upload behavior, network protocol, authentication, transfer limits, and storage behavior must not change.
- "Apple-like" means calm visual hierarchy, careful spacing, clear typography, restrained color, smooth states, and high polish without copying Apple branding.

## Non-goals

- Rewriting the upload backend.
- Changing transfer protocol or discovery behavior.
- Adding account systems, cloud sync, or new packaging.
- Rebranding the whole application.

## Feature Spec

### Problem

The current upload page does not feel as minimal or polished as the target product experience. It should make local file transfer feel simple and trustworthy on both phone and desktop.

### User Scenario

As a nearby user opening the upload page from a phone or desktop browser, I want a clean page where I can quickly choose files, see upload progress, understand success or failure, and recover from errors without confusion.

### Goals

- Provide a refined responsive upload page.
- Preserve existing upload behavior.
- Make empty, dragging, uploading, success, and error states obvious.
- Keep implementation small and aligned with the existing web stack.

### Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | The page presents a minimal upload-first layout on phone and desktop. | AC-1 |
| FR-2 | Users can select files using the existing upload mechanism. | AC-2 |
| FR-3 | Drag-and-drop, if already supported, remains clear and usable. | AC-3 |
| FR-4 | Upload progress, success, and failure states are visible. | AC-4 |
| FR-5 | The redesign does not change backend upload contracts. | AC-5 |

### UX Behavior

- Desktop: centered upload surface, clear title, short helper text, visible device/context label if already available.
- Phone: single-column layout, large touch target, no horizontal scrolling, progress readable at narrow widths.
- States: empty, hover/drag, selected, uploading, success, error.
- Accessibility: visible focus states, semantic buttons/labels, sufficient contrast.

### Risks

- Existing upload JS may mix behavior and presentation.
- Browser file picker and drag behavior can differ on mobile.
- A purely visual change may accidentally change request field names or endpoints.

## Implementation Plan

### Target Repository

- May modify: LanTransfer target repository only.
- Read-only references: skill repository and any design references.

### Proposed Approach

Inspect the existing upload page implementation, identify its HTML/CSS/JS boundaries, then apply a scoped visual redesign while preserving request paths, field names, and upload event behavior.

### Vertical Slice

1. Restyle the existing upload page empty state and file picker.
2. Preserve upload submission.
3. Verify one successful upload and one error state.

### File-level Plan

| File/Area | Change | Requirement |
|---|---|---|
| Existing upload page markup | Adjust structure only as needed for layout and semantics | FR-1, FR-2 |
| Existing upload CSS | Add responsive layout, spacing, typography, states | FR-1, FR-3, FR-4 |
| Existing upload JS | Minimal state class/text updates only if needed | FR-2, FR-4, FR-5 |
| Existing tests/docs | Update only if the project already covers this page | FR-5 |

### Test/Build Plan

- Build: run the repository's normal build command after discovery.
- Tests: run existing relevant tests if present.
- Manual: open the upload page on desktop width and phone width, choose files, upload, inspect progress, verify success and error states.

## Acceptance Criteria

| ID | Criteria | Verification |
|---|---|---|
| AC-1 | Page fits phone and desktop without horizontal scrolling or overlapping text. | Browser manual check at narrow and desktop widths. |
| AC-2 | Selecting one or more files uses the existing upload flow successfully. | Manual upload test. |
| AC-3 | Drag/drop behavior is preserved where supported by the original page. | Desktop drag/drop test. |
| AC-4 | Uploading, success, and failure states are visible and understandable. | Manual success and forced-failure check. |
| AC-5 | Network endpoint, request method, field names, and backend behavior are unchanged. | Code review and network inspection. |

## Final Coding-agent Prompt

You are implementing a scoped redesign of the LanTransfer web upload page.

Target repository, may modify: `[LanTransfer repo path]`
Skill repository, read-only: `[jiapeng-skills repo path]`
Reference repositories, read-only: none unless explicitly provided.

Allowed modifications:
- Existing upload page markup, styles, and minimal page-local state handling.
- Existing tests or docs directly related to the upload page.

Disallowed modifications:
- Do not change backend upload endpoints, request methods, field names, storage behavior, discovery behavior, authentication, packaging, or unrelated UI.
- Do not add dependencies unless the project already has an approved design system package for this page.
- Do not rewrite the web app.

Requirement:
Redesign the upload page to be minimal, polished, Apple-like, and responsive for phone and desktop while preserving existing upload behavior.

Implementation plan:
1. Inspect existing upload page files and identify backend contract points.
2. Apply a scoped responsive layout and visual polish.
3. Preserve file selection and upload behavior.
4. Add or update loading, empty, success, and error states only where needed.
5. Run available build/tests and manually verify desktop and phone widths.

Acceptance criteria:
- Page fits phone and desktop with no overlap or horizontal scrolling.
- Existing file selection and upload still work.
- Drag/drop still works if it worked before.
- Upload progress, success, and error states are visible.
- Backend upload contract is unchanged.

Final summary:
Return files changed, requirement coverage, checks run, manual verification, and remaining risks.

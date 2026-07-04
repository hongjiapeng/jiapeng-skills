---
name: windows-app-manager
description: |
  Controlled Windows app management skill currently powered by winget, with room to add other Windows app providers later.
  Provides safe app operations: search, show, download, install, upgrade, uninstall, resolve-installed, and list-upgrades.
  Use when Codex needs to manage Windows applications, including apps that are installed locally but not discoverable in public winget sources.
  All operations return structured JSON output with consistent schema.
  Designed for Windows Agent integration with security-first approach.
metadata:
  openclaw:
    requires:
      bins:
        - powershell
        - winget
      os:
        - windows
    minPwshVersion: "5.1"
    minWingetVersion: "1.6"
    emoji: "📦"
---

# Windows App Manager Skill

## Overview

This skill provides controlled Windows app management capabilities. The current provider is winget, including winget source packages and locally installed MSIX/ARP apps visible through `winget list`. It is designed as a security-first skill that prevents arbitrary command execution while enabling common app management workflows.

## When to use this skill

Use this skill when the user wants to:

- Search for an application available through WinGet
- Inspect package details before taking action
- Download an installer package without installing it
- Install, upgrade, or uninstall an application
- Resolve a locally installed app display name to exact package IDs before uninstalling
- List applications that have available upgrades

## When NOT to use this skill

Do **not** use this skill for:

- Running arbitrary PowerShell or shell commands
- Editing files, registry keys, services, or scheduled tasks
- Downloading files from custom URLs
- Executing local `.exe`, `.bat`, `.cmd`, or `.ps1` files outside this skill
- Installing software from sources other than approved WinGet sources (winget, msstore)

## Safety rules

1. Only use the 8 supported actions: `search`, `show`, `download`, `install`, `upgrade`, `uninstall`, `resolve-installed`, `list-upgrades`
2. Prefer **exact package IDs** (e.g. `Google.Chrome`) over fuzzy names
3. For `install`, `upgrade`, and `uninstall` — if the package is ambiguous, run `search` or `show` first and return candidates instead of executing
4. Only allow sources `winget` and `msstore`
5. Do not invent or append unsupported WinGet arguments
6. Do not transform this skill into a generic PowerShell executor
7. Treat `uninstall` as high-risk — always require an exact package ID
8. **Never automatically retry** `install`, `upgrade`, or `uninstall` if they fail. Report the failure to the user and let them decide. Retrying may trigger repeated UAC prompts or uninstaller dialogs
9. **Disambiguation is mandatory**: When the user's request matches multiple packages (e.g. "uninstall DevToy" matches both `DevToys.DevToys` and `DevToys.DevToys.Preview`), you **must** list all matching candidates and ask the user which one(s) to operate on. **Never** silently operate on all matches. This applies to `install`, `upgrade`, and especially `uninstall`
10. For uninstall requests by display name, first try `search` when a repository package ID is needed. If `search` finds no package but the app may already be installed, run `resolve-installed` to query local installed packages. If exactly one installed package is returned, uninstall using that exact returned ID. If zero or multiple packages are returned, report candidates or ask for disambiguation; never uninstall all matches.

## Allowed Operations

| Action | Description | Risk Level |
|--------|-------------|-------------|
| `search` | Search for packages | Low |
| `show` | View package details | Low |
| `download` | Download installer only | Medium |
| `install` | Install a package | Medium |
| `upgrade` | Upgrade a package | Medium |
| `uninstall` | Uninstall a package | High |
| `resolve-installed` | Resolve a local installed app name to exact package IDs, including MSIX/ARP IDs | Low |
| `list-upgrades` | List updatable packages | Low |

## Key Design Principles

1. **Fixed Parameter Interface**: No free-form command execution
2. **Whitelisted Sources**: Only pre-approved sources allowed (winget, msstore)
3. **Exact Package Matching**: Uses `--exact` and `--id` flags by default for install/upgrade/uninstall
4. **Structured Output**: All operations return JSON with consistent schema
5. **Safe Process Handling**: Async I/O, timeout support, and proper resource disposal

## Security Constraints

- **No arbitrary command execution**: Only defined actions allowed
- **Source whitelist**: Validated against allowed list (winget, msstore)
- **Uninstall always exact**: `--exact` flag enforced on every uninstall, cannot be overridden
- **Install/upgrade default exact**: `--exact` flag enabled by default, prevents ambiguous installs
- **No arbitrary URI handling**: All operations go through winget CLI directly
- **Argument quoting**: Paths with spaces are automatically quoted

## Usage

Run the wrapper from the skill root via `scripts\windows-app-manager.ps1`. Do not assume `windows-app-manager.ps1` exists directly in the skill root.

```powershell
# Search for packages
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action search -Query "Visual Studio Code"

# Show package details
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action show -PackageId "Microsoft.VisualStudioCode" -Exact

# Download installer only
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action download -PackageId "Google.Chrome" -Source winget -DownloadPath "$env:USERPROFILE\Downloads" -Exact

# Install a package with exact matching
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action install -PackageId "Microsoft.VisualStudioCode" -Source winget -Exact

# Upgrade a package
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action upgrade -PackageId "Git.Git" -Source winget -Exact

# Uninstall (always exact match)
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action uninstall -PackageId "7zip.7zip" -Source winget -Exact

# Resolve a locally installed app when source search finds nothing
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action resolve-installed -Query "微信"

# List upgradeable packages
powershell -ExecutionPolicy Bypass -File .\scripts\windows-app-manager.ps1 -Action list-upgrades
```

## Operational Pitfalls

- If a public `search` returns no package for a display name, continue with `resolve-installed` before uninstalling. Many preinstalled, MSIX, OEM, or localized applications are only visible through the local installed list.
- If `resolve-installed` unexpectedly reports `winget is not installed or not in PATH`, first confirm whether the Windows App Installer alias is actually available with a read-only check such as `Get-Command winget`. On some Windows sessions, the alias may live under `WindowsApps` and a transient wrapper check can fail even though `winget` works.
- When `resolve-installed` is blocked by that alias issue but `winget` is available, a read-only diagnostic fallback is allowed: run `winget list --name "Microsoft Teams" --accept-source-agreements` using the requested display name instead of the example. If it returns exactly one installed row, copy that exact `ID` into the normal `uninstall` action. If it returns zero or multiple rows, report the candidates or ask for disambiguation. Never uninstall every match.
- Do not retry a failed `uninstall` automatically. The fallback above is only for resolving an exact local package ID before the first uninstall attempt.

## Output Format

All operations return structured JSON:
```json
{
  "success": true,
  "action": "search",
  "query": "Visual Studio Code",
  "source": "winget",
  "candidates": [
    { "name": "Microsoft Visual Studio Code", "id": "Microsoft.VisualStudioCode", "version": "1.96.0" }
  ],
  "stdout": "...",
  "stderr": "",
  "exit_code": 0,
  "summary": "Search completed for 'Visual Studio Code'"
}
```

## Error Handling

The skill handles:
- winget not installed
- Package not found
- Network failures
- Permission issues
- Ambiguous matches (returns candidates instead of executing)

## Requirements

- Windows 10 1809+ or Windows 11
- PowerShell 5.1+ (7+ recommended)
- winget 1.6+ (for download support; 1.0+ for other operations)

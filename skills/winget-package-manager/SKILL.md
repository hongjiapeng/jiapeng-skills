---
name: winget-package-manager
description: |
  Controlled Windows package management skill based on winget.
  Provides safe software package operations: search, show, download, install, upgrade, uninstall, and list-upgrades.
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

# Winget Package Manager Skill

## Overview

This skill provides controlled Windows software package management capabilities using winget. It is designed as a security-first skill that prevents arbitrary command execution while enabling common package management workflows.

## When to use this skill

Use this skill when the user wants to:

- Search for an application available through WinGet
- Inspect package details before taking action
- Download an installer package without installing it
- Install, upgrade, or uninstall an application
- List applications that have available upgrades

## When NOT to use this skill

Do **not** use this skill for:

- Running arbitrary PowerShell or shell commands
- Editing files, registry keys, services, or scheduled tasks
- Downloading files from custom URLs
- Executing local `.exe`, `.bat`, `.cmd`, or `.ps1` files outside this skill
- Installing software from sources other than approved WinGet sources (winget, msstore)

## Safety rules

1. Only use the 7 supported actions: `search`, `show`, `download`, `install`, `upgrade`, `uninstall`, `list-upgrades`
2. Prefer **exact package IDs** (e.g. `Google.Chrome`) over fuzzy names
3. For `install`, `upgrade`, and `uninstall` — if the package is ambiguous, run `search` or `show` first and return candidates instead of executing
4. Only allow sources `winget` and `msstore`
5. Do not invent or append unsupported WinGet arguments
6. Do not transform this skill into a generic PowerShell executor
7. Treat `uninstall` as high-risk — always require an exact package ID
8. **Never automatically retry** `install`, `upgrade`, or `uninstall` if they fail. Report the failure to the user and let them decide. Retrying may trigger repeated UAC prompts or uninstaller dialogs

## Allowed Operations

| Action | Description | Risk Level |
|--------|-------------|-------------|
| `search` | Search for packages | Low |
| `show` | View package details | Low |
| `download` | Download installer only | Medium |
| `install` | Install a package | Medium |
| `upgrade` | Upgrade a package | Medium |
| `uninstall` | Uninstall a package | High |
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

```powershell
# Search for packages
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action search -Query "Visual Studio Code"

# Show package details
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action show -PackageId "Microsoft.VisualStudioCode" -Exact

# Download installer only
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action download -PackageId "Google.Chrome" -Source winget -DownloadPath "$env:USERPROFILE\Downloads" -Exact

# Install a package with exact matching
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action install -PackageId "Microsoft.VisualStudioCode" -Source winget -Exact

# Upgrade a package
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action upgrade -PackageId "Git.Git" -Source winget -Exact

# Uninstall (always exact match)
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action uninstall -PackageId "7zip.7zip" -Source winget -Exact

# List upgradeable packages
powershell -ExecutionPolicy Bypass -File .\winget-skill.ps1 -Action list-upgrades
```

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

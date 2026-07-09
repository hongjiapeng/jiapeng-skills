---
name: edge-favorites-show-icon-only
description: Investigate and safely batch-enable or batch-disable Microsoft Edge Favorites bar "Show icon only" on Windows without clearing bookmark names. Use when the user asks where Edge stores the Favorites/Bookmarks bar icon-only state, mentions the Bookmarks show_icon field, wants JSON/profile diffing for Edge favorites, or wants a PowerShell script to set Favorites bar URL items to icon-only or restore name-and-icon display while preserving names and backups.
---

# Edge Favorites Show Icon Only

## Overview

Use this skill for Windows Microsoft Edge profile analysis and safe automation around the Favorites bar right-click option "Show icon only". The confirmed storage location is the profile `Bookmarks` JSON file, where URL bookmark nodes under `roots.bookmark_bar` may contain `show_icon: true|false`.

This skill currently supports Windows only.

## Key Finding

The icon-only state is stored per bookmark URL node:

```text
%LOCALAPPDATA%\Microsoft\Edge\User Data\<Profile>\Bookmarks
roots.bookmark_bar.children[N].show_icon
```

Example:

```json
{
  "name": "Google",
  "show_icon": true,
  "type": "url",
  "url": "https://www.google.com/"
}
```

Do not implement icon-only behavior by clearing `name`. The point of this Edge feature is that `name` remains intact and `show_icon` controls display.

## Safety Rules

- Require Edge to be fully closed before reading baseline captures or writing `Bookmarks`.
- If `msedge.exe` is running during script execution, prompt the user to save Edge work and confirm force-closing Edge before proceeding.
- Never modify files while `msedge.exe` is running; force-close only after explicit user confirmation, unless `-NoPrompt` is used to fail fast instead.
- Only modify `Bookmarks` after confirming target URL nodes contain `show_icon`.
- Do not modify `Preferences`, `Secure Preferences`, `Local State`, SQLite databases, `sync_metadata`, or unknown fields for this task.
- Do not delete folders/bookmarks, reset profiles, clear names, or recalculate unneeded internal metadata.
- Back up `Bookmarks` before every write and report the backup path.
- If the `show_icon` field is absent or the JSON shape differs, stop and report risk instead of guessing.

## Workflow

1. Locate Edge user data:

   ```powershell
   $root = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
   Get-ChildItem -LiteralPath $root -Directory |
     Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }
   ```

2. Check Edge process state:

   ```powershell
   Get-Process msedge -ErrorAction SilentlyContinue
   ```

3. For investigation requests, compare before/after JSON snapshots of:

   ```text
   Bookmarks
   Preferences
   Secure Preferences
   Local State
   ```

   Treat SQLite files such as `Favicons`, `History`, `Shortcuts`, and `Top Sites` as non-destructive observation targets only.

4. If the user wants batch modification and `show_icon` is confirmed, use the bundled script.

## Bundled Script

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 -ProfileName Default -WhatIf
```

Actual update:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 -ProfileName Default
```

Cancel icon-only and restore name-and-icon display:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 -ProfileName Default -DisableShowIconOnly
```

All `Default` / `Profile *` profiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1
```

Cancel icon-only for all `Default` / `Profile *` profiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 -DisableShowIconOnly
```

Include URLs inside Favorites bar folders:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 -ProfileName Default -RecurseFolders
```

Restore a backup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-EdgeFavoritesShowIconOnly.ps1 `
  -ProfileName Default `
  -RestoreBackup "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks.show-icon-backup.YYYYMMDD_HHMMSS"
```

The script:

- prompts when `msedge.exe` is running, warns the user to save work, and force-closes Edge only after the user types `Y`;
- reopens Edge after the operation if the script closed it;
- supports `-NoPrompt` to fail instead of asking, and `-NoRestartEdge` to leave Edge closed;
- scans `Default` / `Profile *` unless `-ProfileName` is specified;
- only processes `roots.bookmark_bar` URL nodes;
- defaults to non-recursive folder handling;
- preserves `name`;
- sets only `show_icon = true` by default, or `show_icon = false` with `-DisableShowIconOnly`;
- backs up `Bookmarks`;
- validates JSON before and after writing;
- reports scanned, changed, already-desired, and skipped counts.

## Reporting

When finishing a task, report:

- profile(s) inspected or modified;
- exact `Bookmarks` path;
- number of URL favorites changed;
- backup path(s);
- whether recursion was used;
- any files that changed during investigation but were not the storage location.

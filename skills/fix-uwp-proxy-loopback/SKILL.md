---
name: fix-uwp-proxy-loopback
description: Diagnose and repair Windows UWP app failures caused by local proxy loopback restrictions. Use when Microsoft Store, Store Purchase App, App Installer, Xbox, or other UWP/AppContainer apps fail to open, initialize, sign in, download, or connect while v2RayN, Clash, sing-box, or another local proxy is enabled on 127.0.0.1 or localhost.
---

# Fix UWP Proxy Loopback

## Overview

Use this skill to handle Windows UWP/AppContainer apps that cannot reach a local proxy such as v2RayN's `127.0.0.1:10809`. The usual fix is to add package family names to the `CheckNetIsolation LoopbackExempt` list, then reset the affected app cache.

Prefer the bundled script for repeatability:

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$script = Join-Path $codexHome "skills\fix-uwp-proxy-loopback\scripts\repair-uwp-loopback.ps1"
powershell -ExecutionPolicy Bypass -File $script
```

To also close Microsoft Store and launch `wsreset.exe`:

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$script = Join-Path $codexHome "skills\fix-uwp-proxy-loopback\scripts\repair-uwp-loopback.ps1"
powershell -ExecutionPolicy Bypass -File $script -ResetStore
```

## Workflow

1. Confirm symptoms: UWP app shows initialization, connection, sign-in, or download errors only when a local proxy client is active.
2. Run the script with default options to detect Store-related package family names and add loopback exemptions.
3. If Microsoft Store is already stuck open, run the script with `-ResetStore`.
4. Reopen the app and test.
5. Only if the app still fails and system components appear to ignore the user proxy, consider `-ImportWinHttpProxy`. Explain that this changes WinHTTP proxy state and can be reverted with `-ResetWinHttpProxy`.

## Script Behavior

The script repairs these packages by default when installed for the current user:

- `Microsoft.WindowsStore`
- `Microsoft.StorePurchaseApp`
- `Microsoft.DesktopAppInstaller`
- `Microsoft.XboxIdentityProvider`
- `Microsoft.GamingServices`
- `Microsoft.XboxGamingOverlay`
- `Microsoft.Xbox.TCUI`

It also prints:

- Current loopback exemption list
- Current user proxy registry settings
- Current WinHTTP proxy settings

It does not import or reset WinHTTP proxy unless explicitly requested.

## Manual Commands

Use manual commands when a script is not appropriate:

```powershell
Get-AppxPackage *Store* | Select-Object Name, PackageFamilyName, Status
CheckNetIsolation.exe LoopbackExempt -a "-n=Microsoft.WindowsStore_8wekyb3d8bbwe"
CheckNetIsolation.exe LoopbackExempt -s
wsreset.exe
```

When a user sees `CheckNetIsolation` return "invalid parameter", first query the real `PackageFamilyName` with `Get-AppxPackage`; do not assume the package family name exists on that machine.

## Safety Notes

- Do not clear the full loopback exemption list with `-c` unless the user explicitly asks.
- Do not default to `netsh winhttp import proxy source=ie`; it can affect system services beyond Store.
- If importing WinHTTP fixes the issue, tell the user they can later revert with:

```powershell
netsh winhttp reset proxy
```

---
name: fix-uwp-proxy-loopback
description: Diagnose and repair Windows AppContainer access to local proxies such as v2RayN, Clash, or sing-box on 127.0.0.1 or localhost. Use for Store/Xbox connectivity failures and Teams/Office sign-in failures involving Windows authentication components, including identity verification errors or 0xCAA70004 while a local proxy is enabled. Do not treat every Teams connectivity or account error as a loopback issue.
---

# Fix Windows App Proxy Loopback

## Scope

Handle local proxy access blocked by Windows AppContainer network isolation. This includes UWP apps and authentication components used by desktop apps. A desktop app can reach the proxy while its separate sign-in broker cannot.

Keep the skill identifier and folder `fix-uwp-proxy-loopback` for existing invocations. The scope includes Windows authentication brokers; it is not a general Teams, Office, VPN, or network repair skill.

## Diagnose before changing exemptions

1. Read the current user proxy (`HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`) and check that the configured local port is listening. Inspect WinHTTP separately; direct WinHTTP access alone does not prove a fault.
2. Test the affected service and login endpoint through that same proxy. Derive the proxy address from the user's configuration rather than assuming port 10809. A successful HTTP response proves that path works for the test process, not for an AppContainer or for account authentication.
3. Inspect installed packages and `CheckNetIsolation.exe LoopbackExempt -s`. Identify the component that fails instead of exempting every installed Microsoft app. Package installation by itself does not establish that an app runs in an AppContainer.
4. For Teams/Office identity errors, inspect recent `Microsoft-Windows-AAD/Operational` events. Look for the underlying error and failing endpoint, not only the wrapper `0xCAA5001C`. `0xCAA70004` means the server or proxy was not found; it supports a network diagnosis but does not prove loopback isolation by itself.

Useful read-only checks:

```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
    Select-Object ProxyEnable, ProxyServer, ProxyOverride, AutoConfigURL
netsh winhttp show proxy
CheckNetIsolation.exe LoopbackExempt -s
Get-AppxPackage Microsoft.AAD.BrokerPlugin |
    Select-Object Name, PackageFamilyName, Status
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-AAD/Operational'
    StartTime = (Get-Date).AddMinutes(-15)
} -MaxEvents 20 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, Message
```

Keep event output focused on timestamps, error codes, and relevant endpoints. Do not copy tokens or unnecessary account identifiers into reports.

## Targeted repair

Resolve the actual `PackageFamilyName` with `Get-AppxPackage`, then add an exemption only for the implicated component. For Teams/Office, that may be `Microsoft.AAD.BrokerPlugin`, rather than the Teams package itself. Other Windows account components should be investigated only when evidence points to them.

Prefer the bundled helper when useful. With no parameters it only reports proxy settings and existing exemptions. Pass exact package names to repair selected installed packages; use `-WhatIf` to preview:

```powershell
$skillHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$script = Join-Path $skillHome 'skills\fix-uwp-proxy-loopback\scripts\repair-uwp-loopback.ps1'
& $script
& $script -PackageNames 'Microsoft.AAD.BrokerPlugin' -WhatIf
& $script -PackageNames 'Microsoft.AAD.BrokerPlugin'
```

For a Store failure, select the relevant packages instead:

```powershell
& $script -PackageNames 'Microsoft.WindowsStore','Microsoft.StorePurchaseApp'
```

The manual equivalent for a broker failure is:

```powershell
$broker = Get-AppxPackage -Name Microsoft.AAD.BrokerPlugin
if (-not $broker) { throw 'Microsoft AAD Broker package was not found.' }
CheckNetIsolation.exe LoopbackExempt -a "-n=$($broker.PackageFamilyName)"
CheckNetIsolation.exe LoopbackExempt -s
```

If the command fails, inspect its output and re-query the package family before retrying. Request elevation only if the actual operation requires it; do not infer failure solely from whether the current shell is elevated.

## Verify and stop

- Confirm the intended package appears in the exemption list. Preserve existing exemptions.
- Have the affected app retry authentication or fully exit and reopen it when needed. Confirm the original symptom clears. No new events alone does not prove success if no authentication retry occurred.
- Report configuration changes separately from verified recovery. If verification is pending, say so.
- If the same failure remains after a retry, inspect fresh errors and reconsider proxy routing, DNS, service availability, or account policy rather than adding unrelated exemptions.

Cache resets are not a routine follow-up. Use `-ResetStore` only for a still-stuck Microsoft Store after the network path is repaired; it closes Store processes and runs `wsreset.exe`. Do not clear Teams/Office credentials or caches by default.

Only consider `-ImportWinHttpProxy` when evidence identifies a failing WinHTTP consumer. Explain that it affects system services, record the previous configuration, and restore that configuration if the attempt does not help. `-ResetWinHttpProxy` resets to direct access; it is a rollback only when the previous state was direct. Never use import and reset together.

Do not clear the full exemption list with `-c`. To undo a newly added broker exemption, use the resolved family name with `LoopbackExempt -d`; do not remove an exemption that predated the repair.

## Confirmed Teams case

Teams displayed “我们无法验证你的身份” while v2RayN's local proxy could reach Teams and Microsoft login endpoints. Recent AAD events showed token refresh failures with `0xCAA70004`. The installed `Microsoft.AAD.BrokerPlugin` package lacked a loopback exemption. Adding only that broker's exemption resolved the symptom, as confirmed by the user. This is a diagnostic example, not a reason to apply that exemption to every sign-in failure.

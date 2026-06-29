---
name: directory-lock-detector
description: "Detect which process is locking or occupying a Windows directory using WMI and PowerShell module scanning."
---

# Directory Lock Detector

Find what process holds a handle on a Windows directory. Pure PowerShell + WMI, no external tools needed.

## Workflow

1. List directory contents to confirm path exists and find exe names for keywords
2. Scan all process modules for DLLs loaded from the target directory
3. Query WMI `Win32_Process` by name pattern (derive keywords from directory exe/folder names)
4. Query WMI `Win32_Service` for matching services
5. Get process details: owner, session ID, memory, start time, command line
6. Report findings

## Key Techniques

### Module Scan (catches DLL load locks)
Write to `.ps1` then execute:
```powershell
Get-Process | ForEach-Object {
  $p = $_
  $p.Modules | ForEach-Object {
    if ($_.FileName -like "$targetDir\*") { report $p, $_ }
  }
}
```
Catches processes with DLLs mapped from the directory. May miss processes that only run an exe from the directory without loading sibling DLLs.

### WMI Process Name Match (wider net ⭐)
```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match 'keyword1|keyword2|...' }
```
Derive search keywords from exe names and folder names found inside the target directory. This is the primary detection method.

### WMI Service Match
```powershell
Get-CimInstance Win32_Service |
  Where-Object { $_.Name -match 'keyword1|keyword2|...' }
```

### Process Detail Lookup
```powershell
$proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"
Invoke-CimMethod -InputObject $proc -MethodName GetOwner
# SessionId: 0 = system service session, not user desktop
```

## Critical Caveats

- **Always write scripts to `.ps1` files then execute** — never use `powershell -Command "..."` with `$_` or `$()` in inline strings; the shell strips them before PowerShell sees them
- Session ID 0 = system service session; may need elevated privileges to stop
- `ExecutablePath` may be empty in WMI if the process was started as a service
- `Handle.exe` (Sysinternals) is the gold standard but often not installed; these methods are fallbacks
- Some processes show no loaded modules from the directory but still hold file handles — WMI name matching catches more

## Output Format

Report per-process:
- PID, Process Name, Executable Path
- Who owns it (user/domain)
- Session ID (0 = system, 1+ = user desktop)
- Memory usage, Start time
- Whether related services exist and their status
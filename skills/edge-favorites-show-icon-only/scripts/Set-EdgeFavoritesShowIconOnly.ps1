[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$UserDataRoot = (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'),

    [string[]]$ProfileName,

    [switch]$RecurseFolders,

    [switch]$DisableShowIconOnly,

    [switch]$NoPrompt,

    [switch]$NoRestartEdge,

    [string]$RestoreBackup
)

$ErrorActionPreference = 'Stop'

function Get-DefaultEdgePath {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return 'msedge.exe'
}

function Ensure-EdgeReadyForProfileWrite {
    param(
        [Parameter(Mandatory)] [bool]$PromptAllowed
    )

    $edge = Get-Process msedge -ErrorAction SilentlyContinue
    if (-not $edge) {
        return [pscustomobject]@{
            WasRunning = $false
            ClosedByScript = $false
            EdgePath = Get-DefaultEdgePath
        }
    }

    $edgePath = @($edge | Where-Object { $_.Path } | Select-Object -ExpandProperty Path -Unique | Select-Object -First 1)
    if (-not $edgePath) {
        $edgePath = Get-DefaultEdgePath
    }

    if (-not $PromptAllowed) {
        throw "Microsoft Edge is running. Please close Edge completely before modifying profile files."
    }

    Write-Warning "Microsoft Edge is currently running."
    Write-Warning "Save any unsaved web form text, downloads, or work in Edge before continuing."
    Write-Host ""
    Write-Host "Running Edge processes:"
    $edge | Select-Object Id, ProcessName, MainWindowTitle, Path | Format-Table -AutoSize
    Write-Host ""

    $answer = Read-Host "Type Y to force close Microsoft Edge and continue; type anything else to cancel"
    if ($answer -notin @('Y', 'y')) {
        throw "Cancelled by user. Edge was left running and no profile files were modified."
    }

    $edge | Stop-Process -Force -ErrorAction Stop
    Start-Sleep -Seconds 2

    $remaining = Get-Process msedge -ErrorAction SilentlyContinue
    if ($remaining) {
        throw "Microsoft Edge is still running after force close. No profile files were modified."
    }

    [pscustomobject]@{
        WasRunning = $true
        ClosedByScript = $true
        EdgePath = $edgePath
    }
}

function Restart-EdgeIfNeeded {
    param(
        $EdgeState,
        [Parameter(Mandatory)] [bool]$RestartAllowed
    )

    if (-not $RestartAllowed -or -not $EdgeState -or -not $EdgeState.ClosedByScript) {
        return
    }

    try {
        if ($EdgeState.EdgePath -and (Test-Path -LiteralPath $EdgeState.EdgePath)) {
            Start-Process -FilePath $EdgeState.EdgePath | Out-Null
        } else {
            Start-Process -FilePath 'msedge.exe' | Out-Null
        }
        Write-Host "Microsoft Edge was reopened."
    } catch {
        Write-Warning "The operation completed, but Microsoft Edge could not be reopened automatically: $($_.Exception.Message)"
    }
}

function Read-JsonFileUtf8 {
    param([Parameter(Mandatory)] [string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $raw | ConvertFrom-Json
}

function Write-JsonFileUtf8 {
    param(
        [Parameter(Mandatory)] $JsonObject,
        [Parameter(Mandatory)] [string]$Path
    )

    $json = $JsonObject | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Get-TargetProfiles {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [string[]]$Names
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        throw "Edge user data root not found: $Root"
    }

    if ($Names -and $Names.Count -gt 0) {
        foreach ($name in $Names) {
            $path = Join-Path $Root $name
            if (-not (Test-Path -LiteralPath $path)) {
                Write-Warning "Profile not found, skipped: $name"
                continue
            }
            Get-Item -LiteralPath $path
        }
        return
    }

    Get-ChildItem -LiteralPath $Root -Directory |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Bookmarks') }
}

function Get-BookmarkBarUrlNodes {
    param(
        [Parameter(Mandatory)] $Node,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [bool]$Recursive
    )

    $results = New-Object System.Collections.Generic.List[object]

    if ($Node.PSObject.Properties.Name -contains 'children') {
        for ($i = 0; $i -lt $Node.children.Count; $i++) {
            $child = $Node.children[$i]
            $childPath = "$Path.children[$i]"

            if ($child.type -eq 'url') {
                $results.Add([pscustomobject]@{
                    Node = $child
                    Path = $childPath
                })
            } elseif ($Recursive -and $child.type -eq 'folder') {
                $nested = Get-BookmarkBarUrlNodes -Node $child -Path $childPath -Recursive $true
                foreach ($item in $nested) {
                    $results.Add($item)
                }
            }
        }
    }

    $results
}

function Set-ProfileShowIconOnly {
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo]$Profile,
        [Parameter(Mandatory)] [bool]$Recursive,
        [Parameter(Mandatory)] [bool]$ShowIconOnly
    )

    $bookmarksPath = Join-Path $Profile.FullName 'Bookmarks'
    if (-not (Test-Path -LiteralPath $bookmarksPath)) {
        Write-Warning "Bookmarks file not found, skipped: $($Profile.Name)"
        return
    }

    $bookmarks = Read-JsonFileUtf8 -Path $bookmarksPath
    if (-not $bookmarks.roots -or -not $bookmarks.roots.bookmark_bar) {
        throw "Invalid Bookmarks structure in profile $($Profile.Name): roots.bookmark_bar not found."
    }

    $targets = @(Get-BookmarkBarUrlNodes -Node $bookmarks.roots.bookmark_bar -Path 'roots.bookmark_bar' -Recursive $Recursive)
    $nodesWithShowIcon = @($targets | Where-Object { $_.Node.PSObject.Properties.Name -contains 'show_icon' })
    if ($targets.Count -gt 0 -and $nodesWithShowIcon.Count -eq 0) {
        throw "No bookmark_bar URL node contains show_icon in profile $($Profile.Name). This Edge version/profile shape is not confirmed safe for this script."
    }

    $changed = 0
    $alreadyDesired = 0
    $skippedMissingField = 0

    foreach ($target in $targets) {
        $node = $target.Node
        if (-not ($node.PSObject.Properties.Name -contains 'show_icon')) {
            $skippedMissingField++
            continue
        }

        if ([bool]$node.show_icon -eq $ShowIconOnly) {
            $alreadyDesired++
            continue
        }

        $node.show_icon = $ShowIconOnly
        $changed++
    }

    if ($changed -eq 0) {
        [pscustomobject]@{
            Profile = $Profile.Name
            BookmarksFile = $bookmarksPath
            BackupFile = ''
            UrlBookmarksScanned = $targets.Count
            Changed = 0
            AlreadyDesired = $alreadyDesired
            SkippedMissingShowIcon = $skippedMissingField
            Status = 'No changes needed'
        }
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $Profile.FullName "Bookmarks.show-icon-backup.$stamp"
    $tempPath = Join-Path $Profile.FullName "Bookmarks.show-icon.tmp.$stamp"

    $desiredValueText = if ($ShowIconOnly) { 'true' } else { 'false' }
    $statusText = if ($ShowIconOnly) { 'Updated to icon only' } else { 'Updated to name and icon' }

    if ($PSCmdlet.ShouldProcess($bookmarksPath, "Set show_icon=$desiredValueText for $changed bookmark_bar URL bookmark(s)")) {
        Copy-Item -LiteralPath $bookmarksPath -Destination $backupPath -Force
        Write-JsonFileUtf8 -JsonObject $bookmarks -Path $tempPath

        # Validate the serialized JSON before replacing the live Bookmarks file.
        [void](Read-JsonFileUtf8 -Path $tempPath)

        Move-Item -LiteralPath $tempPath -Destination $bookmarksPath -Force

        # Validate the final file as stored on disk.
        [void](Read-JsonFileUtf8 -Path $bookmarksPath)
    }

    [pscustomobject]@{
        Profile = $Profile.Name
        BookmarksFile = $bookmarksPath
        BackupFile = $backupPath
        UrlBookmarksScanned = $targets.Count
        Changed = $changed
        AlreadyDesired = $alreadyDesired
        SkippedMissingShowIcon = $skippedMissingField
        Status = $statusText
    }
}

function Restore-BookmarksBackup {
    param(
        [Parameter(Mandatory)] [string]$BackupPath,
        [Parameter(Mandatory)] [string]$Root,
        [string[]]$Names
    )

    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw "Backup file not found: $BackupPath"
    }

    [void](Read-JsonFileUtf8 -Path $BackupPath)

    $profiles = @(Get-TargetProfiles -Root $Root -Names $Names)
    if ($profiles.Count -ne 1) {
        throw "Restore requires exactly one target profile. Pass -ProfileName Default or another single profile name."
    }

    $profile = $profiles[0]
    $bookmarksPath = Join-Path $profile.FullName 'Bookmarks'
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $preRestoreBackup = Join-Path $profile.FullName "Bookmarks.pre-restore.$stamp"

    if ($PSCmdlet.ShouldProcess($bookmarksPath, "Restore from $BackupPath")) {
        if (Test-Path -LiteralPath $bookmarksPath) {
            Copy-Item -LiteralPath $bookmarksPath -Destination $preRestoreBackup -Force
        }
        Copy-Item -LiteralPath $BackupPath -Destination $bookmarksPath -Force
        [void](Read-JsonFileUtf8 -Path $bookmarksPath)
    }

    [pscustomobject]@{
        Profile = $profile.Name
        RestoredFrom = $BackupPath
        BookmarksFile = $bookmarksPath
        PreRestoreBackup = $preRestoreBackup
        Status = 'Restored'
    }
}

$edgeState = $null
try {
    $edgeState = Ensure-EdgeReadyForProfileWrite -PromptAllowed (-not [bool]$NoPrompt)

    if ($RestoreBackup) {
        Restore-BookmarksBackup -BackupPath $RestoreBackup -Root $UserDataRoot -Names $ProfileName
        return
    }

    $profiles = @(Get-TargetProfiles -Root $UserDataRoot -Names $ProfileName)
    if ($profiles.Count -eq 0) {
        throw "No matching Edge profiles with a Bookmarks file were found."
    }

    $showIconOnly = -not [bool]$DisableShowIconOnly
    foreach ($profile in $profiles) {
        Set-ProfileShowIconOnly -Profile $profile -Recursive ([bool]$RecurseFolders) -ShowIconOnly $showIconOnly
    }
} finally {
    Restart-EdgeIfNeeded -EdgeState $edgeState -RestartAllowed (-not [bool]$NoRestartEdge)
}

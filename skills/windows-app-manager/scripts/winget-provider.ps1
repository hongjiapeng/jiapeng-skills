<#
.SYNOPSIS
    Winget Wrapper - Core package management functions.

.DESCRIPTION
    Provides controlled and secure wrapper functions for winget operations.
    Designed to be dot-sourced by windows-app-manager.ps1.
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest

# --- Constants ---
$script:AllowedSources = @('winget', 'msstore')
$script:DefaultTimeout = 300

# --- Utility Functions ---

function Test-WingetAvailable {
    try {
        $output = & winget --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return [ordered]@{ Available = $true; Version = ($output | Out-String).Trim() }
        }
        return [ordered]@{ Available = $false; Version = $null }
    }
    catch {
        return [ordered]@{ Available = $false; Version = $null }
    }
}

function Test-SourceAllowed {
    param([string]$Source)
    return ($script:AllowedSources -contains $Source)
}

function Test-SafeDownloadPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return $false
    }

    foreach ($char in [System.IO.Path]::GetInvalidPathChars()) {
        if ($fullPath.Contains($char)) { return $false }
    }

    return $true
}

function Convert-SearchOutputToCandidates {
    param([Parameter(Mandatory)][string]$Text)

    $lines = $Text -split '\r\n|\n|\r' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $candidates = [System.Collections.Generic.List[object]]::new()

    foreach ($line in $lines) {
        if ($line -match '^\s*Name\s+Id\s+Version') { continue }
        if ($line -match '^\s*-+\s*-+\s*-+') { continue }
        if ($line -match '[\u2580-\u259F]') { continue }
        # ID must contain a dot (reverse-domain style, e.g. "DevToys-app.DevToys")
        # This anchors the split so package names with spaces don't break parsing
        if ($line -match '^\s*(.+?)\s+([\w][\w\-]*\.[\w\.\-]+)\s+(.+?)\s*$') {
            $candidates.Add([ordered]@{
                name    = $Matches[1].Trim()
                id      = $Matches[2].Trim()
                version = $Matches[3].Trim()
            })
        }
    }

    return , $candidates.ToArray()
}

function Convert-InstalledListOutputToCandidates {
    param([Parameter(Mandatory)][string]$Text)

    $lines = $Text -split '\r\n|\n|\r' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $candidates = [System.Collections.Generic.List[object]]::new()
    $header = $lines | Where-Object { $_ -match '(^|\s)ID(\s|$)' -and $_ -match 'Version' } | Select-Object -First 1

    if ($header) {
        $idStart = $header.IndexOf('ID')
        $versionMatch = [regex]::Match($header, 'Version', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $versionStart = $versionMatch.Index
        $sourceMatch = [regex]::Match($header, 'Source', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $sourceStart = if ($sourceMatch.Success -and $sourceMatch.Index -gt $versionStart) { $sourceMatch.Index } else { -1 }
        $minWidth = if ($sourceStart -gt 0) { $sourceStart + 1 } else { $versionStart + 1 }

        foreach ($line in $lines) {
            if ($line -eq $header) { continue }
            if ($line.Trim() -match '^-+$') { continue }
            if ($line.Length -lt $versionStart) { continue }

            $padded = $line.PadRight($minWidth)
            $name = $padded.Substring(0, $idStart).Trim()
            $id = $padded.Substring($idStart, $versionStart - $idStart).Trim()
            $version = if ($sourceStart -gt 0) {
                $padded.Substring($versionStart, $sourceStart - $versionStart).Trim()
            } else {
                $padded.Substring($versionStart).Trim()
            }
            $source = if ($sourceStart -gt 0 -and $line.Length -gt $sourceStart) { $line.Substring($sourceStart).Trim() } else { "" }

            if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($id)) { continue }

            $candidate = [ordered]@{
                name    = $name
                id      = $id
                version = $version
            }
            if (-not [string]::IsNullOrWhiteSpace($source)) { $candidate.source = $source }
            if ($id.IndexOf([char]0x2026) -ge 0) { $candidate.truncated = $true }

            $candidates.Add($candidate)
        }

        return $candidates.ToArray()
    }

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^-+$') { continue }

        $parts = @([regex]::Split($trimmed, '\s{2,}') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($parts.Count -lt 3) { continue }

        if ($parts[1] -ieq 'Id' -or $parts[1] -eq 'ID') { continue }
        if ($parts[0] -match '^-+$' -or $parts[1] -match '^-+$') { continue }

        $candidate = [ordered]@{
            name    = $parts[0].Trim()
            id      = $parts[1].Trim()
            version = $parts[2].Trim()
        }

        if ($parts.Count -ge 4) { $candidate.available = $parts[3].Trim() }
        if ($parts.Count -ge 5) { $candidate.source = $parts[4].Trim() }

        $candidates.Add($candidate)
    }

    return $candidates.ToArray()
}

function Convert-InstalledDetailsOutputToCandidates {
    param([Parameter(Mandatory)][string]$Text)

    $lines = $Text -split '\r\n|\n|\r'
    $candidates = [System.Collections.Generic.List[object]]::new()
    $current = $null

    foreach ($line in $lines) {
        if ($line -match '^\s*(?:\(\d+/\d+\)\s+)?(.+?)\s+\[(.+)\]\s*$') {
            if ($null -ne $current) { $candidates.Add($current) }
            $current = [ordered]@{
                name    = $Matches[1].Trim()
                id      = $Matches[2].Trim()
                version = ""
            }
            continue
        }

        if ($null -eq $current) { continue }

        if ($line -match '^\s*([^:]+):\s*(.+?)\s*$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            if ($key -eq 'Version' -or [string]::IsNullOrWhiteSpace($current.version)) {
                $current.version = $value
            } elseif ($key -eq 'Publisher') {
                $current.publisher = $value
            } elseif ($key -eq 'Installer Type') {
                $current.installer_type = $value
            } elseif ($key -eq 'Installed Scope') {
                $current.scope = $value
            } elseif ($key -eq 'Install Location') {
                $current.install_location = $value
            } elseif ($key -eq 'Package Family Name') {
                $current.package_family_name = $value
            }
        }
    }

    if ($null -ne $current) { $candidates.Add($current) }

    return $candidates.ToArray()
}

function Invoke-WingetCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [int]$TimeoutSeconds = $script:DefaultTimeout
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "winget"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    # Quote arguments containing spaces for safe command-line passing
    # (ArgumentList is .NET Core only, not available in PowerShell 5.1)
    $psi.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '\s') { "`"$_`"" } else { $_ }
    }) -join ' '

    $process = $null
    try {
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi
        $process.Start() | Out-Null

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEnd()
        $stdout = $stdoutTask.Result

        $completed = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $completed) {
            try { $process.Kill() } catch { }
            return [ordered]@{
                ExitCode = -1
                Stdout   = $stdout
                Stderr   = "Operation timed out after ${TimeoutSeconds}s"
                TimedOut = $true
            }
        }

        return [ordered]@{
            ExitCode = $process.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
            TimedOut = $false
        }
    }
    catch {
        return [ordered]@{
            ExitCode = -1
            Stdout   = ""
            Stderr   = $_.Exception.Message
            TimedOut = $false
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }
}

# --- Package Operations ---

function Search-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string]$Source = "winget"
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "search"; error = "Source '$Source' not allowed. Allowed: $($script:AllowedSources -join ', ')" }
    }

    $cmdArgs = @("search", $Query, "--source", $Source, "--accept-source-agreements")
    $result = Invoke-WingetCommand -Arguments $cmdArgs
    $candidates = Convert-SearchOutputToCandidates -Text $result.Stdout

    return [ordered]@{
        success    = ($result.ExitCode -eq 0)
        action     = "search"
        query      = $Query
        source     = $Source
        candidates = $candidates
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($result.ExitCode -eq 0) { "Search completed for '$Query'" } else { "Search failed" }
    }
}

function Show-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = "winget"
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "show"; error = "Source '$Source' not allowed" }
    }

    $cmdArgs = @("show", "--id", $PackageId, "--source", $Source, "--accept-source-agreements")
    $result = Invoke-WingetCommand -Arguments $cmdArgs

    return [ordered]@{
        success    = ($result.ExitCode -eq 0)
        action     = "show"
        package_id = $PackageId
        source     = $Source
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($result.ExitCode -eq 0) { "Package details for $PackageId" } else { "Show failed" }
    }
}

function Save-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$DownloadPath,
        [string]$Source = "winget"
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "download"; error = "Source '$Source' not allowed" }
    }

    if (-not (Test-SafeDownloadPath $DownloadPath)) {
        return [ordered]@{ success = $false; action = "download"; error = "Invalid download path: $DownloadPath" }
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($DownloadPath)
    if (-not (Test-Path $resolvedPath)) {
        try {
            New-Item -Path $resolvedPath -ItemType Directory -Force | Out-Null
        }
        catch {
            return [ordered]@{ success = $false; action = "download"; error = "Cannot create directory: $($_.Exception.Message)" }
        }
    }

    $cmdArgs = @("download", "--id", $PackageId, "--download-directory", $resolvedPath,
                 "--source", $Source, "--accept-source-agreements", "--accept-package-agreements")
    $result = Invoke-WingetCommand -Arguments $cmdArgs -TimeoutSeconds 600

    return [ordered]@{
        success       = ($result.ExitCode -eq 0)
        action        = "download"
        package_id    = $PackageId
        source        = $Source
        download_path = $resolvedPath
        stdout        = $result.Stdout
        stderr        = $result.Stderr
        exit_code     = $result.ExitCode
        summary       = if ($result.ExitCode -eq 0) { "Downloaded $PackageId to $resolvedPath" } else { "Download failed" }
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = "winget",
        [switch]$Exact
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "install"; error = "Source '$Source' not allowed" }
    }

    $cmdArgs = @("install", "--id", $PackageId, "--source", $Source,
                 "--accept-source-agreements", "--accept-package-agreements", "--silent")
    if ($Exact) { $cmdArgs += "--exact" }

    $result = Invoke-WingetCommand -Arguments $cmdArgs -TimeoutSeconds 600

    return [ordered]@{
        success    = ($result.ExitCode -eq 0)
        action     = "install"
        package_id = $PackageId
        source     = $Source
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($result.ExitCode -eq 0) { "Successfully installed $PackageId" } else { "Install failed" }
    }
}

function Update-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = "winget",
        [switch]$Exact
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "upgrade"; error = "Source '$Source' not allowed" }
    }

    $cmdArgs = @("upgrade", "--id", $PackageId, "--source", $Source,
                 "--accept-source-agreements", "--accept-package-agreements", "--silent")
    if ($Exact) { $cmdArgs += "--exact" }

    $result = Invoke-WingetCommand -Arguments $cmdArgs -TimeoutSeconds 600

    return [ordered]@{
        success    = ($result.ExitCode -eq 0)
        action     = "upgrade"
        package_id = $PackageId
        source     = $Source
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($result.ExitCode -eq 0) { "Successfully upgraded $PackageId" } else { "Upgrade failed" }
    }
}

function Uninstall-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = "winget"
    )

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "uninstall"; error = "Source '$Source' not allowed" }
    }

    # Uninstall always requires exact matching for safety
    $cmdArgs = @("uninstall", "--id", $PackageId, "--source", $Source,
                 "--accept-source-agreements", "--silent", "--exact")
    $result = Invoke-WingetCommand -Arguments $cmdArgs

    # winget exit code alone is unreliable - some uninstallers return 0 even when cancelled.
    # Verify by checking if the package is still listed after uninstall.
    $verified = $false
    if ($result.ExitCode -eq 0) {
        $checkArgs = @("list", "--id", $PackageId, "--exact", "--accept-source-agreements")
        $check = Invoke-WingetCommand -Arguments $checkArgs -TimeoutSeconds 30
        # If the package is no longer found, winget list returns non-zero or empty output
        $verified = ($check.ExitCode -ne 0) -or ($check.Stdout -notmatch [regex]::Escape($PackageId))
    }

    $actualSuccess = ($result.ExitCode -eq 0) -and $verified

    return [ordered]@{
        success    = $actualSuccess
        action     = "uninstall"
        package_id = $PackageId
        source     = $Source
        verified   = $verified
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($actualSuccess) {
            "Successfully uninstalled $PackageId (verified)"
        } elseif ($result.ExitCode -eq 0 -and -not $verified) {
            "Uninstall reported success but package still appears installed. The uninstaller may have been cancelled."
        } else {
            "Uninstall failed"
        }
    }
}

function Resolve-InstalledWingetPackage {
    param([Parameter(Mandatory)][string]$Query)

    $cmdArgs = @("list", "--name", $Query, "--details", "--accept-source-agreements")
    $result = Invoke-WingetCommand -Arguments $cmdArgs
    if ([string]::IsNullOrWhiteSpace($result.Stdout)) {
        $candidates = @()
    } else {
        $candidates = @(Convert-InstalledDetailsOutputToCandidates -Text $result.Stdout)
    }
    if ($candidates.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.Stdout)) {
        $candidates = @(Convert-InstalledListOutputToCandidates -Text $result.Stdout)
    }

    $matchState = if ($candidates.Count -eq 0) {
        "none"
    } elseif ($candidates.Count -eq 1) {
        "single"
    } else {
        "multiple"
    }

    return [ordered]@{
        success     = ($result.ExitCode -eq 0 -and $candidates.Count -gt 0)
        action      = "resolve-installed"
        query       = $Query
        candidates  = $candidates
        match_state = $matchState
        stdout      = $result.Stdout
        stderr      = $result.Stderr
        exit_code   = $result.ExitCode
        summary     = if ($candidates.Count -eq 1) {
            "Resolved one installed package for '$Query'"
        } elseif ($candidates.Count -gt 1) {
            "Resolved multiple installed packages for '$Query'; disambiguation required"
        } else {
            "No installed package matched '$Query'"
        }
    }
}

function Get-WingetUpgradeablePackages {
    param([string]$Source = "winget")

    if (-not (Test-SourceAllowed $Source)) {
        return [ordered]@{ success = $false; action = "list-upgrades"; error = "Source '$Source' not allowed" }
    }

    $cmdArgs = @("upgrade", "--source", $Source, "--accept-source-agreements")
    $result = Invoke-WingetCommand -Arguments $cmdArgs
    $candidates = Convert-SearchOutputToCandidates -Text $result.Stdout

    return [ordered]@{
        success    = ($result.ExitCode -eq 0)
        action     = "list-upgrades"
        source     = $Source
        candidates = $candidates
        stdout     = $result.Stdout
        stderr     = $result.Stderr
        exit_code  = $result.ExitCode
        summary    = if ($result.ExitCode -eq 0) { "Upgradeable packages listed" } else { "No upgradeable packages or check failed" }
    }
}

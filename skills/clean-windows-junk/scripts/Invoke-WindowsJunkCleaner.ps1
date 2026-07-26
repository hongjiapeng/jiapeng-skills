[CmdletBinding()]
param(
    [ValidateSet('List', 'ValidateRules', 'Scan', 'Clean')]
    [string]$Action = 'List',

    [string]$RulesPath,

    [string[]]$Entry,

    [string]$Query,

    [string]$PlanPath,

    [string]$ConfirmPlanId,

    [switch]$AllowRisky
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-StableJson {
    param([Parameter(Mandatory = $true)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 20 -Compress)
}

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $algorithm.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-NormalizedFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) {
        $full = $full.TrimEnd('\', '/')
    }
    return $full
}

function Test-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [bool]$AllowEqual = $false
    )

    $normalizedPath = Get-NormalizedFullPath -Path $Path
    $normalizedRoot = Get-NormalizedFullPath -Path $Root
    if ($normalizedPath.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $AllowEqual
    }

    $prefix = $normalizedRoot
    if (-not $prefix.EndsWith('\')) {
        $prefix += '\'
    }
    return $normalizedPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-AllowedRoots {
    $roots = New-Object System.Collections.ArrayList

    $candidates = @(
        [pscustomobject]@{ Label = 'Temp'; Path = [System.IO.Path]::GetTempPath(); AllowEqual = $true },
        [pscustomobject]@{ Label = 'LocalAppData'; Path = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData); AllowEqual = $false },
        [pscustomobject]@{ Label = 'AppData'; Path = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData); AllowEqual = $false },
        [pscustomobject]@{ Label = 'ProgramData'; Path = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData); AllowEqual = $false },
        [pscustomobject]@{ Label = 'WindowsTemp'; Path = (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) 'Temp'); AllowEqual = $true }
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate.Path)) {
            [void]$roots.Add([pscustomobject]@{
                Label = $candidate.Label
                Path = Get-NormalizedFullPath -Path $candidate.Path
                AllowEqual = $candidate.AllowEqual
            })
        }
    }
    return @($roots)
}

function Get-SafeRootForDirectory {
    param([Parameter(Mandatory = $true)][string]$Directory)

    if (-not [System.IO.Path]::IsPathRooted($Directory)) {
        throw "Resolved path is not absolute: $Directory"
    }
    if ($Directory.StartsWith('\\')) {
        throw "UNC paths are not allowed: $Directory"
    }
    if ($Directory -match '%[^%]+%') {
        throw "Path contains an unresolved environment variable: $Directory"
    }

    $full = Get-NormalizedFullPath -Path $Directory
    $matchedRoot = $null
    foreach ($allowed in (Get-AllowedRoots)) {
        if (Test-PathWithin -Path $full -Root $allowed.Path -AllowEqual $allowed.AllowEqual) {
            $matchedRoot = $allowed
            break
        }
    }
    if ($null -eq $matchedRoot) {
        throw "Path is outside the cleanup allowlist: $full"
    }

    if (Test-Path -LiteralPath $full) {
        $current = Get-Item -LiteralPath $full -Force
        while ($null -ne $current) {
            if (($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse points are not allowed: $($current.FullName)"
            }
            if ($current.FullName.Equals($matchedRoot.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
                break
            }
            $parent = Split-Path -Parent $current.FullName
            if ([string]::IsNullOrWhiteSpace($parent) -or $parent.Equals($current.FullName, [System.StringComparison]::OrdinalIgnoreCase)) {
                break
            }
            if (-not (Test-Path -LiteralPath $parent)) {
                break
            }
            $current = Get-Item -LiteralPath $parent -Force
        }
    }

    return $matchedRoot
}

function Expand-WinappPath {
    param([Parameter(Mandatory = $true)][string]$Value)

    $windows = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    $system = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $systemDrive = [System.IO.Path]::GetPathRoot($windows).TrimEnd('\')

    $variables = [ordered]@{
        '%LocalLowAppData%' = (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) 'AppData\LocalLow')
        '%CommonAppData%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
        '%ProgramFilesX86%' = $programFilesX86
        '%SystemRoot%' = $windows
        '%WinDir%' = $windows
        '%System%' = $system
        '%UserProfile%' = $userProfile
        '%Documents%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        '%Desktop%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
        '%Music%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic)
        '%Pictures%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures)
        '%Videos%' = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyVideos)
        '%SystemDrive%' = $systemDrive
        '%Tmp%' = [System.IO.Path]::GetTempPath().TrimEnd('\')
    }

    $expanded = $Value.Trim()
    foreach ($token in $variables.Keys) {
        $replacement = [string]$variables[$token]
        if (-not [string]::IsNullOrWhiteSpace($replacement)) {
            $expanded = [regex]::Replace(
                $expanded,
                [regex]::Escape($token),
                [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement },
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
        }
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($expanded)
    if ($expanded -match '%[^%]+%') {
        throw "Unsupported or unresolved environment variable in path: $Value"
    }
    return $expanded
}

function Resolve-SafeDirectories {
    param([Parameter(Mandatory = $true)][string]$PathPattern)

    $expanded = Expand-WinappPath -Value $PathPattern
    if (-not [System.IO.Path]::IsPathRooted($expanded)) {
        throw "Expanded path is not absolute: $expanded"
    }
    if ($expanded.StartsWith('\\')) {
        throw "UNC paths are not allowed: $expanded"
    }

    $fullPattern = [System.IO.Path]::GetFullPath($expanded)
    $root = [System.IO.Path]::GetPathRoot($fullPattern)
    $relative = $fullPattern.Substring($root.Length)
    $segments = @($relative -split '[\\/]' | Where-Object { $_ -ne '' })

    $firstWildcard = -1
    for ($index = 0; $index -lt $segments.Count; $index++) {
        if ($segments[$index] -match '[*?]') {
            $firstWildcard = $index
            break
        }
    }

    if ($firstWildcard -lt 0) {
        [void](Get-SafeRootForDirectory -Directory $fullPattern)
        if (Test-Path -LiteralPath $fullPattern -PathType Container) {
            return ,(Get-NormalizedFullPath -Path $fullPattern)
        }
        return @()
    }

    $literalPrefix = $root
    if ($firstWildcard -gt 0) {
        $literalPrefix = Join-Path $root ([string]::Join('\', $segments[0..($firstWildcard - 1)]))
    }
    [void](Get-SafeRootForDirectory -Directory $literalPrefix)

    $candidates = @($root)
    foreach ($segment in $segments) {
        $next = New-Object System.Collections.ArrayList
        foreach ($candidate in $candidates) {
            if ($segment -match '[*?]') {
                if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
                    continue
                }
                try {
                    foreach ($match in [System.IO.Directory]::EnumerateDirectories($candidate, $segment, [System.IO.SearchOption]::TopDirectoryOnly)) {
                        [void]$next.Add($match)
                    }
                }
                catch {
                    continue
                }
            }
            else {
                $joined = Join-Path $candidate $segment
                if (Test-Path -LiteralPath $joined -PathType Container) {
                    [void]$next.Add($joined)
                }
            }
        }
        $candidates = @($next)
        if ($candidates.Count -eq 0) {
            break
        }
    }

    $safe = New-Object System.Collections.ArrayList
    foreach ($candidate in $candidates) {
        [void](Get-SafeRootForDirectory -Directory $candidate)
        [void]$safe.Add((Get-NormalizedFullPath -Path $candidate))
    }
    return @($safe | Sort-Object -Unique)
}

function New-WinappEntry {
    param([Parameter(Mandatory = $true)][string]$Name)

    $displayName = $Name -replace '\s+\*$', ''
    return [pscustomobject]@{
        RawName = $Name
        Name = $displayName
        Default = $true
        Warning = ''
        DetectFiles = New-Object System.Collections.ArrayList
        DetectRegistry = New-Object System.Collections.ArrayList
        SpecialDetect = New-Object System.Collections.ArrayList
        FileKeys = New-Object System.Collections.ArrayList
        RegKeys = New-Object System.Collections.ArrayList
        ExcludeKeys = New-Object System.Collections.ArrayList
    }
}

function Read-WinappRules {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Rules file not found: $Path"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $lines = @(Get-Content -LiteralPath $resolvedPath)
    $entries = New-Object System.Collections.ArrayList
    $current = $null
    $version = ''
    $isWinapp3 = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^;\s*Version:\s*(.+)$' -and [string]::IsNullOrWhiteSpace($version)) {
            $version = $Matches[1].Trim()
        }
        if ($trimmed -match '(?i)Winapp3') {
            $isWinapp3 = $true
        }
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith(';')) {
            continue
        }
        if ($trimmed -match '^\[(.+)\]$') {
            if ($null -ne $current) {
                [void]$entries.Add($current)
            }
            $current = New-WinappEntry -Name $Matches[1].Trim()
            continue
        }
        if ($null -eq $current -or $trimmed -notmatch '^([^=]+)=(.*)$') {
            continue
        }

        $key = $Matches[1].Trim()
        $value = $Matches[2].Trim()
        if ($key -ieq 'Default') {
            $current.Default = $value -ieq 'True'
        }
        elseif ($key -ieq 'Warning') {
            $current.Warning = $value
        }
        elseif ($key -match '^(?i)DetectFile\d*$') {
            [void]$current.DetectFiles.Add($value)
        }
        elseif ($key -match '^(?i)Detect\d*$') {
            [void]$current.DetectRegistry.Add($value)
        }
        elseif ($key -match '^(?i)SpecialDetect\d*$') {
            [void]$current.SpecialDetect.Add($value)
        }
        elseif ($key -match '^(?i)FileKey\d+$') {
            [void]$current.FileKeys.Add($value)
        }
        elseif ($key -match '^(?i)RegKey\d+$') {
            [void]$current.RegKeys.Add($value)
        }
        elseif ($key -match '^(?i)ExcludeKey\d+$') {
            [void]$current.ExcludeKeys.Add($value)
        }
    }
    if ($null -ne $current) {
        [void]$entries.Add($current)
    }

    return [pscustomobject]@{
        Path = $resolvedPath
        Version = $version
        Sha256 = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash.ToLowerInvariant()
        IsWinapp3 = $isWinapp3
        Entries = @($entries)
    }
}

function Test-DetectFile {
    param([Parameter(Mandatory = $true)][string]$Pattern)

    try {
        $expanded = Expand-WinappPath -Value $Pattern
        if ($expanded -match '[*?]') {
            return $null -ne (Get-Item -Path $expanded -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
        }
        return Test-Path -LiteralPath $expanded
    }
    catch {
        return $false
    }
}

function Test-SpecialDetect {
    param([Parameter(Mandatory = $true)][string]$Value)

    $patterns = @{
        'DET_CHROME' = '%LocalAppData%\Google\Chrome\User Data'
        'DET_FIREFOX' = '%AppData%\Mozilla\Firefox'
        'DET_EDGE' = '%LocalAppData%\Microsoft\Edge\User Data'
        'DET_OPERA' = '%AppData%\Opera Software\Opera Stable'
        'DET_THUNDERBIRD' = '%AppData%\Thunderbird'
        'DET_WINSTORE' = '%LocalAppData%\Packages'
    }
    if (-not $patterns.ContainsKey($Value.ToUpperInvariant())) {
        return $false
    }
    return Test-DetectFile -Pattern $patterns[$Value.ToUpperInvariant()]
}

function Get-EntryDetection {
    param([Parameter(Mandatory = $true)]$WinappEntry)

    foreach ($pattern in $WinappEntry.DetectFiles) {
        if (Test-DetectFile -Pattern $pattern) {
            return [pscustomobject]@{ Installed = $true; Supported = $true; Method = 'DetectFile' }
        }
    }
    foreach ($special in $WinappEntry.SpecialDetect) {
        if (Test-SpecialDetect -Value $special) {
            return [pscustomobject]@{ Installed = $true; Supported = $true; Method = 'SpecialDetect' }
        }
    }

    $hasSupportedMethod = $WinappEntry.DetectFiles.Count -gt 0 -or $WinappEntry.SpecialDetect.Count -gt 0
    if ($hasSupportedMethod) {
        return [pscustomobject]@{ Installed = $false; Supported = $true; Method = 'NotDetected' }
    }
    if ($WinappEntry.DetectRegistry.Count -gt 0) {
        return [pscustomobject]@{ Installed = $false; Supported = $false; Method = 'RegistryDetectionUnsupported' }
    }
    return [pscustomobject]@{ Installed = $false; Supported = $false; Method = 'NoSupportedDetection' }
}

function Get-EntryRisk {
    param([Parameter(Mandatory = $true)]$WinappEntry)

    $reasons = New-Object System.Collections.ArrayList
    if (-not $WinappEntry.Default) {
        [void]$reasons.Add('Default=False')
    }
    if (-not [string]::IsNullOrWhiteSpace($WinappEntry.Warning)) {
        [void]$reasons.Add("Warning: $($WinappEntry.Warning)")
    }
    if ($WinappEntry.RegKeys.Count -gt 0) {
        [void]$reasons.Add("$($WinappEntry.RegKeys.Count) registry rule(s) will be ignored")
    }

    $level = 'low'
    if (-not $WinappEntry.Default -or -not [string]::IsNullOrWhiteSpace($WinappEntry.Warning)) {
        $level = 'high'
    }
    elseif ($WinappEntry.RegKeys.Count -gt 0) {
        $level = 'medium'
    }

    return [pscustomobject]@{
        Level = $level
        RequiresAllowRisky = $level -eq 'high'
        Reasons = @($reasons)
    }
}

function Parse-FileKey {
    param([Parameter(Mandatory = $true)][string]$Value)

    $parts = @($Value -split '\|')
    if ($parts.Count -lt 1 -or [string]::IsNullOrWhiteSpace($parts[0])) {
        throw "Invalid FileKey: $Value"
    }

    $path = $parts[0].Trim()
    $pattern = '*'
    $flag = ''
    if ($parts.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
        if ($parts[1] -match '^(?i)(RECURSE|REMOVESELF)$') {
            $flag = $parts[1].ToUpperInvariant()
        }
        else {
            $pattern = $parts[1].Trim()
        }
    }
    if ($parts.Count -ge 3 -and $parts[2] -match '^(?i)(RECURSE|REMOVESELF)$') {
        $flag = $parts[2].ToUpperInvariant()
    }

    return [pscustomobject]@{
        Path = $path
        Patterns = @($pattern -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Recurse = $flag -eq 'RECURSE' -or $flag -eq 'REMOVESELF'
        RemoveSelfRequested = $flag -eq 'REMOVESELF'
    }
}

function Get-ResolvedExclusions {
    param([Parameter(Mandatory = $true)]$WinappEntry)

    $rules = New-Object System.Collections.ArrayList
    foreach ($raw in $WinappEntry.ExcludeKeys) {
        $parts = @($raw -split '\|')
        if ($parts.Count -lt 2) {
            continue
        }
        $type = $parts[0].Trim().ToUpperInvariant()
        if ($type -ne 'FILE' -and $type -ne 'PATH') {
            continue
        }
        $pattern = '*'
        if ($parts.Count -ge 3 -and -not [string]::IsNullOrWhiteSpace($parts[2])) {
            $pattern = $parts[2].Trim()
        }
        try {
            foreach ($directory in (Resolve-SafeDirectories -PathPattern $parts[1].Trim())) {
                [void]$rules.Add([pscustomobject]@{
                    Type = $type
                    Directory = $directory
                    Pattern = $pattern
                })
            }
        }
        catch {
            continue
        }
    }
    return @($rules)
}

function Test-FileExcluded {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Exclusions
    )

    $full = Get-NormalizedFullPath -Path $File
    $parent = Get-NormalizedFullPath -Path (Split-Path -Parent $full)
    $name = Split-Path -Leaf $full

    foreach ($rule in $Exclusions) {
        if ($rule.Type -eq 'FILE') {
            if ($parent.Equals($rule.Directory, [System.StringComparison]::OrdinalIgnoreCase) -and $name -like $rule.Pattern) {
                return $true
            }
        }
        elseif ($rule.Type -eq 'PATH') {
            if ((Test-PathWithin -Path $full -Root $rule.Directory -AllowEqual $false) -and $name -like $rule.Pattern) {
                return $true
            }
        }
    }
    return $false
}

function Get-FilesSafe {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [bool]$Recurse = $false
    )

    [void](Get-SafeRootForDirectory -Directory $Root)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        $directory = [string]$stack.Pop()
        foreach ($pattern in $Patterns) {
            try {
                foreach ($file in [System.IO.Directory]::EnumerateFiles($directory, $pattern, [System.IO.SearchOption]::TopDirectoryOnly)) {
                    if ($seen.Add($file)) {
                        $file
                    }
                }
            }
            catch {
                continue
            }
        }

        if (-not $Recurse) {
            continue
        }
        try {
            foreach ($child in [System.IO.Directory]::EnumerateDirectories($directory, '*', [System.IO.SearchOption]::TopDirectoryOnly)) {
                try {
                    $item = Get-Item -LiteralPath $child -Force
                    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                        $stack.Push($child)
                    }
                }
                catch {
                    continue
                }
            }
        }
        catch {
            continue
        }
    }
}

function Resolve-ExactEntries {
    param(
        [Parameter(Mandatory = $true)]$Rules,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    $selected = New-Object System.Collections.ArrayList
    foreach ($name in $Names) {
        $matches = @($Rules.Entries | Where-Object {
            $_.Name.Equals($name, [System.StringComparison]::OrdinalIgnoreCase) -or
            $_.RawName.Equals($name, [System.StringComparison]::OrdinalIgnoreCase)
        })
        if ($matches.Count -eq 0) {
            $suggestions = @($Rules.Entries | Where-Object {
                $_.Name.IndexOf($name, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            } | Select-Object -First 5 -ExpandProperty Name)
            $suffix = ''
            if ($suggestions.Count -gt 0) {
                $suffix = " Candidates: $([string]::Join(', ', $suggestions))"
            }
            throw "Exact entry not found: $name.$suffix"
        }
        if ($matches.Count -gt 1) {
            throw "Entry name is ambiguous in the rules file: $name"
        }
        if (-not ($selected | Where-Object { $_.Name -ieq $matches[0].Name })) {
            [void]$selected.Add($matches[0])
        }
    }
    return @($selected)
}

function Invoke-ValidateRules {
    param([Parameter(Mandatory = $true)]$Rules)

    $issues = New-Object System.Collections.ArrayList
    $invalidFileKeys = 0
    if ($Rules.IsWinapp3) {
        [void]$issues.Add('Winapp3 rules are rejected.')
    }
    if ($Rules.Entries.Count -eq 0) {
        [void]$issues.Add('No cleaner entries were parsed.')
    }
    foreach ($winappEntry in $Rules.Entries) {
        foreach ($fileKey in $winappEntry.FileKeys) {
            try {
                [void](Parse-FileKey -Value $fileKey)
            }
            catch {
                $invalidFileKeys++
                [void]$issues.Add("$($winappEntry.Name): $($_.Exception.Message)")
            }
        }
    }

    return [ordered]@{
        success = $issues.Count -eq 0
        action = 'ValidateRules'
        rules_path = $Rules.Path
        rules_version = $Rules.Version
        rules_sha256 = $Rules.Sha256
        entry_count = $Rules.Entries.Count
        invalid_file_key_count = $invalidFileKeys
        is_winapp3 = $Rules.IsWinapp3
        issues = @($issues)
    }
}

function Invoke-ListEntries {
    param(
        [Parameter(Mandatory = $true)]$Rules,
        [string]$Filter
    )

    if ($Rules.IsWinapp3) {
        throw 'Winapp3 rules are rejected.'
    }
    $source = @($Rules.Entries)
    if (-not [string]::IsNullOrWhiteSpace($Filter)) {
        $source = @($source | Where-Object {
            $_.Name.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    }

    $items = New-Object System.Collections.ArrayList
    foreach ($winappEntry in $source) {
        $detection = Get-EntryDetection -WinappEntry $winappEntry
        $risk = Get-EntryRisk -WinappEntry $winappEntry
        [void]$items.Add([ordered]@{
            name = $winappEntry.Name
            installed = $detection.Installed
            detection_supported = $detection.Supported
            detection_method = $detection.Method
            default = $winappEntry.Default
            warning = $winappEntry.Warning
            risk_level = $risk.Level
            file_rule_count = $winappEntry.FileKeys.Count
            registry_rule_count = $winappEntry.RegKeys.Count
        })
    }

    return [ordered]@{
        success = $true
        action = 'List'
        rules_path = $Rules.Path
        rules_version = $Rules.Version
        result_count = $items.Count
        entries = @($items)
    }
}

function Invoke-Scan {
    param(
        [Parameter(Mandatory = $true)]$Rules,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$OutputPlanPath
    )

    if ($Rules.IsWinapp3) {
        throw 'Winapp3 rules are rejected.'
    }
    if ($Names.Count -eq 0) {
        throw 'Scan requires at least one exact -Entry name.'
    }

    $selected = Resolve-ExactEntries -Rules $Rules -Names $Names
    $plannedFiles = New-Object System.Collections.ArrayList
    $entrySummaries = New-Object System.Collections.ArrayList
    $skippedRules = New-Object System.Collections.ArrayList
    $seenFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $requiresAllowRisky = $false

    foreach ($winappEntry in $selected) {
        $detection = Get-EntryDetection -WinappEntry $winappEntry
        $risk = Get-EntryRisk -WinappEntry $winappEntry
        if ($risk.RequiresAllowRisky) {
            $requiresAllowRisky = $true
        }

        $entryFileCount = 0
        $entryBytes = [int64]0
        if (-not $detection.Installed) {
            [void]$skippedRules.Add([ordered]@{
                entry = $winappEntry.Name
                rule = ''
                reason = $detection.Method
            })
        }
        else {
            $exclusions = @(Get-ResolvedExclusions -WinappEntry $winappEntry)
            foreach ($rawFileKey in $winappEntry.FileKeys) {
                try {
                    $fileKey = Parse-FileKey -Value $rawFileKey
                    $directories = @(Resolve-SafeDirectories -PathPattern $fileKey.Path)
                    foreach ($directory in $directories) {
                        foreach ($file in (Get-FilesSafe -Root $directory -Patterns $fileKey.Patterns -Recurse $fileKey.Recurse)) {
                            $full = Get-NormalizedFullPath -Path $file
                            if ($seenFiles.Contains($full) -or (Test-FileExcluded -File $full -Exclusions $exclusions)) {
                                continue
                            }
                            $item = Get-Item -LiteralPath $full -Force
                            if ($item.PSIsContainer -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                                continue
                            }
                            [void]$seenFiles.Add($full)
                            [void]$plannedFiles.Add([ordered]@{
                                path = $full
                                bytes = [int64]$item.Length
                                last_write_utc_ticks = [int64]$item.LastWriteTimeUtc.Ticks
                                entry = $winappEntry.Name
                            })
                            $entryFileCount++
                            $entryBytes += [int64]$item.Length
                        }
                    }
                }
                catch {
                    [void]$skippedRules.Add([ordered]@{
                        entry = $winappEntry.Name
                        rule = $rawFileKey
                        reason = $_.Exception.Message
                    })
                }
            }
        }

        [void]$entrySummaries.Add([ordered]@{
            name = $winappEntry.Name
            detected = $detection.Installed
            detection_method = $detection.Method
            default = $winappEntry.Default
            warning = $winappEntry.Warning
            risk_level = $risk.Level
            risk_reasons = @($risk.Reasons)
            file_count = $entryFileCount
            estimated_bytes = $entryBytes
            ignored_registry_rule_count = $winappEntry.RegKeys.Count
        })
    }

    $sortedFiles = @($plannedFiles | Sort-Object path)
    $totalBytes = [int64]0
    foreach ($plannedFile in $sortedFiles) {
        $totalBytes += [int64]$plannedFile.bytes
    }

    $payload = [ordered]@{
        schema_version = 1
        created_at = [DateTimeOffset]::Now.ToString('o')
        rules = [ordered]@{
            path = $Rules.Path
            version = $Rules.Version
            sha256 = $Rules.Sha256
        }
        entries = @($entrySummaries)
        files = $sortedFiles
        skipped_rules = @($skippedRules)
        file_count = $sortedFiles.Count
        estimated_bytes = $totalBytes
        requires_allow_risky = $requiresAllowRisky
        registry_deletion_enabled = $false
        directory_deletion_enabled = $false
    }
    $payloadJson = ConvertTo-StableJson -InputObject $payload
    $planId = 'sha256:' + (Get-StringSha256 -Value $payloadJson)
    $plan = [ordered]@{
        plan_id = $planId
        payload = $payload
    }

    $fullPlanPath = Get-NormalizedFullPath -Path $OutputPlanPath
    $parent = Split-Path -Parent $fullPlanPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fullPlanPath -Encoding utf8

    return [ordered]@{
        success = $true
        action = 'Scan'
        plan_id = $planId
        plan_path = $fullPlanPath
        rules_version = $Rules.Version
        entries = @($entrySummaries)
        file_count = $sortedFiles.Count
        estimated_bytes = $totalBytes
        skipped_rules = @($skippedRules)
        requires_allow_risky = $requiresAllowRisky
        confirmation_required = $true
    }
}

function Invoke-Clean {
    param(
        [Parameter(Mandatory = $true)][string]$InputPlanPath,
        [Parameter(Mandatory = $true)][string]$ConfirmedPlanId,
        [bool]$RiskAccepted
    )

    if (-not (Test-Path -LiteralPath $InputPlanPath -PathType Leaf)) {
        throw "Plan file not found: $InputPlanPath"
    }
    if ([string]::IsNullOrWhiteSpace($ConfirmedPlanId)) {
        throw 'Clean requires -ConfirmPlanId from an explicitly confirmed scan result.'
    }

    $plan = Get-Content -LiteralPath $InputPlanPath -Raw | ConvertFrom-Json
    if ($null -eq $plan.plan_id -or $null -eq $plan.payload) {
        throw 'Invalid cleanup plan structure.'
    }
    $calculatedPlanId = 'sha256:' + (Get-StringSha256 -Value (ConvertTo-StableJson -InputObject $plan.payload))
    if (-not $calculatedPlanId.Equals([string]$plan.plan_id, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Cleanup plan integrity check failed.'
    }
    if (-not $calculatedPlanId.Equals($ConfirmedPlanId, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Confirmed plan ID does not match the saved cleanup plan.'
    }
    if ([bool]$plan.payload.requires_allow_risky -and -not $RiskAccepted) {
        throw 'This plan contains Default=False or Warning entries. Explicitly confirm the displayed risks, then rerun with -AllowRisky.'
    }

    $rulesPathFromPlan = [string]$plan.payload.rules.path
    if (-not (Test-Path -LiteralPath $rulesPathFromPlan -PathType Leaf)) {
        throw "The rules file recorded in the plan is no longer available: $rulesPathFromPlan"
    }
    $currentRulesHash = (Get-FileHash -LiteralPath $rulesPathFromPlan -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $currentRulesHash.Equals([string]$plan.payload.rules.sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The rules file changed after the scan. Create a new cleanup plan.'
    }

    $deleted = New-Object System.Collections.ArrayList
    $stale = New-Object System.Collections.ArrayList
    $failed = New-Object System.Collections.ArrayList
    $missing = New-Object System.Collections.ArrayList
    $bytes = [int64]0

    foreach ($planned in @($plan.payload.files)) {
        $path = [string]$planned.path
        try {
            $full = Get-NormalizedFullPath -Path $path
            if (-not $full.Equals($path, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw 'Path is not normalized as recorded.'
            }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                [void]$missing.Add($full)
                continue
            }

            [void](Get-SafeRootForDirectory -Directory (Split-Path -Parent $full))
            $item = Get-Item -LiteralPath $full -Force
            if ($item.PSIsContainer -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw 'Target is not a regular file.'
            }
            if ([int64]$item.Length -ne [int64]$planned.bytes -or
                [int64]$item.LastWriteTimeUtc.Ticks -ne [int64]$planned.last_write_utc_ticks) {
                [void]$stale.Add($full)
                continue
            }

            $length = [int64]$item.Length
            [System.IO.File]::Delete($full)
            [void]$deleted.Add($full)
            $bytes += $length
        }
        catch {
            [void]$failed.Add([ordered]@{
                path = $path
                reason = $_.Exception.Message
            })
        }
    }

    return [ordered]@{
        success = $failed.Count -eq 0
        action = 'Clean'
        plan_id = $calculatedPlanId
        completed_at = [DateTimeOffset]::Now.ToString('o')
        deleted_count = $deleted.Count
        reclaimed_bytes = $bytes
        stale_count = $stale.Count
        missing_count = $missing.Count
        failed_count = $failed.Count
        deleted = @($deleted)
        stale = @($stale)
        missing = @($missing)
        failed = @($failed)
    }
}

try {
    $result = $null
    switch ($Action) {
        'ValidateRules' {
            if ([string]::IsNullOrWhiteSpace($RulesPath)) {
                throw 'ValidateRules requires -RulesPath.'
            }
            $rules = Read-WinappRules -Path $RulesPath
            $result = Invoke-ValidateRules -Rules $rules
        }
        'List' {
            if ([string]::IsNullOrWhiteSpace($RulesPath)) {
                throw 'List requires -RulesPath.'
            }
            $rules = Read-WinappRules -Path $RulesPath
            $result = Invoke-ListEntries -Rules $rules -Filter $Query
        }
        'Scan' {
            if ([string]::IsNullOrWhiteSpace($RulesPath)) {
                throw 'Scan requires -RulesPath.'
            }
            if ([string]::IsNullOrWhiteSpace($PlanPath)) {
                throw 'Scan requires -PlanPath.'
            }
            if ($null -eq $Entry -or $Entry.Count -eq 0) {
                throw 'Scan requires at least one exact -Entry name.'
            }
            $rules = Read-WinappRules -Path $RulesPath
            $result = Invoke-Scan -Rules $rules -Names $Entry -OutputPlanPath $PlanPath
        }
        'Clean' {
            if ([string]::IsNullOrWhiteSpace($PlanPath)) {
                throw 'Clean requires -PlanPath.'
            }
            $result = Invoke-Clean -InputPlanPath $PlanPath -ConfirmedPlanId $ConfirmPlanId -RiskAccepted $AllowRisky.IsPresent
        }
    }
    $result | ConvertTo-Json -Depth 20
}
catch {
    [ordered]@{
        success = $false
        action = $Action
        error = $_.Exception.Message
        error_type = $_.Exception.GetType().FullName
        script_stack_trace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 10
    exit 1
}

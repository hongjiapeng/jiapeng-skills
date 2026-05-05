param(
    [string]$Root = ".",
    [string]$Solution,
    [string[]]$ProductRoots = @(),
    [switch]$IncludeSymbolScan,
    [switch]$ShowAbsoluteRoot,
    [int]$MaxSymbolCandidates = 80
)

$ErrorActionPreference = "Stop"

function Get-FullPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return (Get-Location).Path
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

$RootFull = Get-FullPath $Root
Set-Location $RootFull

function ConvertTo-RelativePath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $root = $RootFull.TrimEnd('\', '/')
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\', '/').Replace('/', '\')
    }
    return $full.Replace('/', '\')
}

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        $full = [System.IO.Path]::GetFullPath($Path)
    }
    else {
        $full = [System.IO.Path]::GetFullPath((Join-Path $RootFull $Path))
    }
    return ConvertTo-RelativePath $full
}

function Read-XmlOrNull([string]$Path) {
    try {
        [xml](Get-Content $Path -Raw)
    }
    catch {
        $null
    }
}

function Get-ProjectOutputType([string]$ProjectPath) {
    $xml = Read-XmlOrNull (Join-Path $RootFull $ProjectPath)
    if ($null -eq $xml) { return "" }
    $node = $xml.SelectSingleNode('//*[local-name()="OutputType"]')
    if ($null -eq $node) { return "" }
    return $node.InnerText
}

function Add-Edge($Map, [string]$From, [string]$To) {
    if (-not $Map.ContainsKey($From)) {
        $Map[$From] = New-Object System.Collections.Generic.List[string]
    }
    if (-not $Map[$From].Contains($To)) {
        $Map[$From].Add($To) | Out-Null
    }
}

$solutionPath = $Solution
if ([string]::IsNullOrWhiteSpace($solutionPath)) {
    $solutions = Get-ChildItem -Path $RootFull -Filter *.sln -File | Sort-Object Name
    if ($solutions.Count -gt 0) {
        $solutionPath = ConvertTo-RelativePath $solutions[0].FullName
    }
}
elseif (Test-Path $solutionPath) {
    $solutionPath = ConvertTo-RelativePath (Get-FullPath $solutionPath)
}

$solutionProjects = @{}
if ($solutionPath -and (Test-Path (Join-Path $RootFull $solutionPath))) {
    $slnText = Get-Content (Join-Path $RootFull $solutionPath) -Raw
    [regex]::Matches($slnText, 'Project\("\{[^}]+\}"\) = "([^"]+)", "([^"]+)", "\{([^}]+)\}"') | ForEach-Object {
        $name = $_.Groups[1].Value
        $path = $_.Groups[2].Value
        if ($path -match '\.(csproj|vcxproj|shproj|wapproj)$') {
            $solutionProjects[(Resolve-RepoPath $path)] = $name
        }
    }
}

$projectExtensions = @(".csproj", ".vcxproj", ".shproj", ".wapproj")
$allProjectFiles = Get-ChildItem -Path $RootFull -Recurse -File |
    Where-Object {
        $projectExtensions -contains $_.Extension -and
        $_.FullName -notmatch '\\(bin|obj)\\'
    }

$allProjects = @{}
foreach ($file in $allProjectFiles) {
    $allProjects[(ConvertTo-RelativePath $file.FullName)] = $true
}

$edges = @{}
foreach ($project in $allProjects.Keys) {
    $edges[$project] = New-Object System.Collections.Generic.List[string]
    $projectFull = Join-Path $RootFull $project
    $projectDir = Split-Path $projectFull
    $xml = Read-XmlOrNull $projectFull
    if ($null -eq $xml) { continue }

    foreach ($node in $xml.SelectNodes('//*[local-name()="ProjectReference"]')) {
        if ([string]::IsNullOrWhiteSpace($node.Include)) { continue }
        $target = ConvertTo-RelativePath ([System.IO.Path]::GetFullPath((Join-Path $projectDir $node.Include)))
        if ($allProjects.ContainsKey($target)) {
            Add-Edge $edges $project $target
        }
    }

    foreach ($node in $xml.SelectNodes('//*[local-name()="Import"]')) {
        if ([string]::IsNullOrWhiteSpace($node.Project)) { continue }
        if ($node.Project -notmatch '\.projitems$') { continue }
        $projitems = [System.IO.Path]::GetFullPath((Join-Path $projectDir $node.Project))
        $sharedDir = Split-Path $projitems
        Get-ChildItem -Path $sharedDir -Filter *.shproj -File -ErrorAction SilentlyContinue | ForEach-Object {
            $target = ConvertTo-RelativePath $_.FullName
            if ($allProjects.ContainsKey($target)) {
                Add-Edge $edges $project $target
            }
        }
    }
}

if ($ProductRoots.Count -eq 0) {
    $packageRoots = @($solutionProjects.Keys | Where-Object { $_ -match '\.wapproj$' })
    if ($packageRoots.Count -gt 0) {
        $ProductRoots = $packageRoots
    }
    else {
        foreach ($project in $solutionProjects.Keys) {
            if ($project -notmatch '\.csproj$') { continue }
            if ($project -match '(?i)(test|tests|sample|example|debug)') { continue }
            $outputType = Get-ProjectOutputType $project
            if ($outputType -match '^(Exe|WinExe)$') {
                $ProductRoots += $project
            }
        }
    }
    $ProductRoots = $ProductRoots | Select-Object -Unique
}
else {
    $ProductRoots = $ProductRoots | ForEach-Object { Resolve-RepoPath $_ }
}

$reachable = New-Object 'System.Collections.Generic.HashSet[string]'
$queue = New-Object 'System.Collections.Generic.Queue[string]'
foreach ($rootProject in $ProductRoots) {
    if ($allProjects.ContainsKey($rootProject) -and -not $reachable.Contains($rootProject)) {
        $reachable.Add($rootProject) | Out-Null
        $queue.Enqueue($rootProject)
    }
}

while ($queue.Count -gt 0) {
    $project = $queue.Dequeue()
    foreach ($target in $edges[$project]) {
        if ($allProjects.ContainsKey($target) -and -not $reachable.Contains($target)) {
            $reachable.Add($target) | Out-Null
            $queue.Enqueue($target)
        }
    }
}

function Write-Section([string]$Title, $Items) {
    ""
    "## $Title"
    $array = @($Items) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    if ($array.Count -eq 0) {
        "- None found."
        return
    }
    foreach ($item in $array) {
        "- $item"
    }
}

"# Unused Code Candidate Report"
""
if ($ShowAbsoluteRoot) {
    "Root: $RootFull"
}
else {
    "Root: ."
}
if ($solutionPath) {
    "Solution: $solutionPath"
}
else {
    "Solution: not found"
}
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
""
"## Summary"
"- Solution projects: $($solutionProjects.Count)"
"- Project files found: $($allProjects.Count)"
"- Product roots: $($ProductRoots.Count)"
"- Product-reachable projects: $($reachable.Count)"
""
"## Product Roots"
if ($ProductRoots.Count -eq 0) {
    "- None selected. Re-run with -ProductRoots for better reachability results."
}
else {
    $ProductRoots | Sort-Object | ForEach-Object { "- $_" }
}

$notInSolution = $allProjects.Keys |
    Sort-Object |
    Where-Object { -not $solutionProjects.ContainsKey($_) -and $_ -notmatch '_wpftmp\.csproj$' }
Write-Section "Project Files Not In Solution" $notInSolution

$wpfTemps = $allProjects.Keys | Sort-Object | Where-Object { $_ -match '_wpftmp\.csproj$' }
Write-Section "WPF Temporary Project Files" $wpfTemps

$unreachable = $solutionProjects.Keys |
    Sort-Object |
    Where-Object { -not $reachable.Contains($_) } |
    ForEach-Object { "$_ [$($solutionProjects[$_])]" }
Write-Section "Solution Projects Not Reachable From Product Roots" $unreachable

$duplicateNames = $solutionProjects.GetEnumerator() |
    Group-Object Value |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
        $paths = $_.Group | ForEach-Object { $_.Key } | Sort-Object
        "$($_.Name): $($paths -join '; ')"
    }
Write-Section "Duplicate Solution Project Names" $duplicateNames

$removedExisting = New-Object System.Collections.Generic.List[string]
$removedGlobs = New-Object System.Collections.Generic.List[string]
$noneSource = New-Object System.Collections.Generic.List[string]

foreach ($project in $allProjects.Keys | Where-Object { $_ -match '\.csproj$' }) {
    $projectFull = Join-Path $RootFull $project
    $projectDir = Split-Path $projectFull
    $xml = Read-XmlOrNull $projectFull
    if ($null -eq $xml) { continue }

    foreach ($kind in @("Compile", "Page", "EmbeddedResource")) {
        foreach ($node in $xml.SelectNodes("//*[local-name()='$kind']")) {
            $remove = $node.Remove
            if ([string]::IsNullOrWhiteSpace($remove)) { continue }
            if ($remove.Contains("*")) {
                $prefix = $remove -replace '\*\*.*$', ''
                $globPath = [System.IO.Path]::GetFullPath((Join-Path $projectDir $prefix))
                if (Test-Path $globPath) {
                    $removedGlobs.Add("$project removes $kind glob '$remove' (path exists)") | Out-Null
                }
            }
            else {
                $candidate = [System.IO.Path]::GetFullPath((Join-Path $projectDir $remove))
                if (Test-Path $candidate) {
                    $removedExisting.Add("$project removes $kind '$remove' -> $(ConvertTo-RelativePath $candidate)") | Out-Null
                }
            }
        }
    }

    foreach ($node in $xml.SelectNodes("//*[local-name()='None']")) {
        $include = $node.Include
        if ([string]::IsNullOrWhiteSpace($include)) { continue }
        if ($include -match '\.cs$' -and -not $include.Contains("*")) {
            $candidate = [System.IO.Path]::GetFullPath((Join-Path $projectDir $include))
            if (Test-Path $candidate) {
                $noneSource.Add("$project includes source as None '$include' -> $(ConvertTo-RelativePath $candidate)") | Out-Null
            }
        }
    }
}

Write-Section "Existing Files Explicitly Removed From Build Items" ($removedExisting | Sort-Object)
Write-Section "Existing Directories Explicitly Removed By Globs" ($removedGlobs | Sort-Object)
Write-Section "C# Source Files Included As None" ($noneSource | Sort-Object)

$trackedGenerated = @()
if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $trackedGenerated = git ls-files 2>$null |
            Where-Object {
                $_ -match '(^|/)(bin|obj|x64|CoverageReport)/' -or
                $_ -match '_wpftmp\.csproj$'
            }
    }
    catch {
        $trackedGenerated = @()
    }
}
Write-Section "Git-Tracked Generated Or Temporary Artifacts" ($trackedGenerated | Sort-Object)

if ($IncludeSymbolScan) {
    ""
    "## Symbol-Level Candidates"
    "These are low-confidence candidates. Review XAML, reflection, DI, serialization, routes, and plugin/config loading before deleting."

    $searchRoots = @()
    foreach ($rootProject in $ProductRoots) {
        if ($rootProject -match '\.csproj$') {
            $searchRoots += (Split-Path (Join-Path $RootFull $rootProject))
        }
    }
    if ($searchRoots.Count -eq 0) { $searchRoots = @($RootFull) }
    $searchRoots = $searchRoots | Select-Object -Unique

    $symbolCandidates = New-Object System.Collections.Generic.List[object]
    foreach ($searchRoot in $searchRoots) {
        Get-ChildItem -Path $searchRoot -Recurse -File -Include *.cs |
            Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.Name -notmatch '\.(g|Designer)\.cs$' } |
            ForEach-Object {
                $relativeFile = ConvertTo-RelativePath $_.FullName
                $text = Get-Content $_.FullName -Raw
                $defs = [regex]::Matches($text, '(?m)^\s*(?:public|internal|private|protected|sealed|abstract|static|partial|record|readonly|unsafe|\s)*\s*(class|interface|enum|struct|record)\s+([A-Za-z_][A-Za-z0-9_]*)')
                foreach ($def in $defs) {
                    $name = $def.Groups[2].Value
                    $pattern = "\b$([regex]::Escape($name))\b"
                    $matches = @(rg -n --pcre2 $pattern -g '*.cs' -g '*.xaml' -g '*.json' -g '!bin/**' -g '!obj/**' . 2>$null)
                    $other = @($matches | Where-Object {
                        ($_ -notlike "$($relativeFile):*") -and ($_ -notlike ".\$($relativeFile):*")
                    })
                    if ($matches.Count -le 2 -or $other.Count -eq 0) {
                        $symbolCandidates.Add([pscustomobject]@{
                            Name = $name
                            Kind = $def.Groups[1].Value
                            File = $relativeFile
                            Matches = $matches.Count
                            OtherFiles = $other.Count
                        }) | Out-Null
                    }
                }
            }
    }

    $symbolCandidates |
        Sort-Object OtherFiles, Matches, File, Name |
        Select-Object -First $MaxSymbolCandidates |
        ForEach-Object { '- {0} `{1}` in `{2}` (matches: {3}, other files: {4})' -f $_.Kind, $_.Name, $_.File, $_.Matches, $_.OtherFiles }
}

""
"## Interpretation Notes"
"- High confidence does not mean delete blindly; build and test after cleanup."
"- Product reachability depends on selected roots. Re-run with -ProductRoots if the default roots are wrong."
"- Static scans can miss reflection, XAML bindings, native exports, dynamically loaded assemblies, config-driven routes, and packaging-only assets."

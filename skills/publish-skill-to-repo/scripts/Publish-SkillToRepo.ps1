[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,62}$')]
    [string]$SkillName,

    [Parameter(Mandatory = $true)]
    [string]$RepoSkillsDir,

    [string]$CodexSkillsDir = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $HOME '.codex\skills' }),

    [switch]$DryRun,

    [switch]$Validate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-WithinPath {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $childFull = Get-FullPath $Child
    $parentFull = (Get-FullPath $Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $childFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-LinkInfo {
    param([Parameter(Mandatory = $true)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return [pscustomobject]@{
            Exists = $false
            IsDirectory = $false
            IsLink = $false
            LinkType = $null
            Target = $null
            FullName = $Path
        }
    }

    return [pscustomobject]@{
        Exists = $true
        IsDirectory = $item.PSIsContainer
        IsLink = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        LinkType = $item.LinkType
        Target = (($item.Target | ForEach-Object { $_ }) -join ';')
        FullName = $item.FullName
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    if ($DryRun) {
        Write-Host "[dry-run] $Description"
        return
    }

    Write-Host "[run] $Description"
    & $Action
}

if (-not (Test-Path -LiteralPath $RepoSkillsDir -PathType Container)) {
    throw "RepoSkillsDir does not exist or is not a directory: $RepoSkillsDir"
}

if (-not (Test-Path -LiteralPath $CodexSkillsDir -PathType Container)) {
    throw "CodexSkillsDir does not exist or is not a directory: $CodexSkillsDir"
}

$repoRoot = Resolve-ExistingPath $RepoSkillsDir
$codexRoot = Resolve-ExistingPath $CodexSkillsDir
$source = Join-Path $codexRoot $SkillName
$target = Join-Path $repoRoot $SkillName
$targetFull = Get-FullPath $target

if (-not (Test-WithinPath -Child $targetFull -Parent $repoRoot)) {
    throw "Target escapes RepoSkillsDir: $targetFull"
}

$sourceInfo = Get-LinkInfo $source
$targetInfo = Get-LinkInfo $target

Write-Host "SkillName      : $SkillName"
Write-Host "Codex path     : $source"
Write-Host "Repo path      : $targetFull"
Write-Host "Codex exists   : $($sourceInfo.Exists) link=$($sourceInfo.IsLink) target=$($sourceInfo.Target)"
Write-Host "Repo exists    : $($targetInfo.Exists) link=$($targetInfo.IsLink)"

if ($sourceInfo.Exists -and $sourceInfo.IsLink) {
    if ($sourceInfo.Target -and ((Get-FullPath $sourceInfo.Target).Equals($targetFull, [System.StringComparison]::OrdinalIgnoreCase))) {
        Write-Host "Already linked correctly."
    } else {
        throw "Codex skill path is already a link, but it does not point at the requested repo target."
    }
} elseif ($sourceInfo.Exists -and $targetInfo.Exists) {
    throw "Both Codex path and repo path exist as real entries. Refusing to merge or overwrite automatically."
} elseif ($sourceInfo.Exists -and -not $targetInfo.Exists) {
    if (-not $sourceInfo.IsDirectory) {
        throw "Codex path exists but is not a directory: $source"
    }
    Invoke-Step "Move skill directory into repo" {
        Move-Item -LiteralPath $source -Destination $targetFull
    }
    Invoke-Step "Create junction from Codex skills directory to repo copy" {
        cmd /c mklink /J "$source" "$targetFull" | Write-Host
    }
} elseif (-not $sourceInfo.Exists -and $targetInfo.Exists) {
    if (-not $targetInfo.IsDirectory) {
        throw "Repo target exists but is not a directory: $targetFull"
    }
    Invoke-Step "Create junction from Codex skills directory to existing repo copy" {
        cmd /c mklink /J "$source" "$targetFull" | Write-Host
    }
} else {
    throw "Neither Codex skill nor repo target exists. Create the skill first, then publish it."
}

$finalSource = Get-LinkInfo $source
$finalTarget = Get-LinkInfo $targetFull
Write-Host "Final Codex link: exists=$($finalSource.Exists) link=$($finalSource.IsLink) target=$($finalSource.Target)"
Write-Host "Final repo dir  : exists=$($finalTarget.Exists) dir=$($finalTarget.IsDirectory)"

if ($Validate -and -not $DryRun) {
    $validator = Join-Path $codexRoot '.system\skill-creator\scripts\quick_validate.py'
    if (Test-Path -LiteralPath $validator) {
        $env:PYTHONUTF8 = '1'
        python $validator $targetFull
    } else {
        Write-Warning "Skill validator not found: $validator"
    }
}

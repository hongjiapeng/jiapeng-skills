<#
.SYNOPSIS
    Create directory junctions for skills into the global agent skills directory.

.DESCRIPTION
    Links skill folders from this repository into C:\Users\<user>\.agents\skills\
    so that all VS Code Copilot agents can discover and invoke them.
    Uses directory junctions (no administrator privileges required).

.PARAMETER SkillName
    Name of a single skill to link. If omitted, all skills are linked.

.PARAMETER AgentsSkillsDir
    Target directory for the links. Defaults to C:\Users\<current user>\.agents\skills.

.EXAMPLE
    # Link all skills
    .\scripts\Link-Skills.ps1

.EXAMPLE
    # Link a specific skill
    .\scripts\Link-Skills.ps1 -SkillName hpxwsvr-incremental-update
#>

[CmdletBinding()]
param(
    [string] $SkillName,
    [string] $AgentsSkillsDir = "$env:USERPROFILE\.agents\skills"
)

$ErrorActionPreference = 'Stop'

# Resolve the skills source directory relative to this script
$repoRoot   = Split-Path $PSScriptRoot -Parent
$skillsRoot = Join-Path $repoRoot 'skills'

# Collect skills to process
if ($SkillName) {
    $skillDirs = @(Get-Item (Join-Path $skillsRoot $SkillName) -ErrorAction Stop)
} else {
    $skillDirs = Get-ChildItem $skillsRoot -Directory
}

if (-not $skillDirs) {
    Write-Warning "No skills found under '$skillsRoot'."
    exit 0
}

# Ensure target directory exists
if (-not (Test-Path $AgentsSkillsDir)) {
    New-Item -ItemType Directory -Path $AgentsSkillsDir -Force | Out-Null
    Write-Host "Created directory: $AgentsSkillsDir"
}

foreach ($skill in $skillDirs) {
    $linkPath = Join-Path $AgentsSkillsDir $skill.Name

    if (Test-Path $linkPath) {
        $existing = Get-Item $linkPath -Force
        if ($existing.LinkType -in 'Junction','SymbolicLink' -and $existing.Target -eq $skill.FullName) {
            Write-Host "  [skip]    $($skill.Name)  (already linked)"
            continue
        } else {
            Write-Warning "  [conflict] '$linkPath' already exists and is not a link to this skill. Skipping."
            continue
        }
    }

    New-Item -ItemType Junction -Path $linkPath -Target $skill.FullName | Out-Null
    Write-Host "  [linked]  $($skill.Name)"
    Write-Host "            $linkPath"
    Write-Host "            -> $($skill.FullName)"
}

Write-Host "`nDone."

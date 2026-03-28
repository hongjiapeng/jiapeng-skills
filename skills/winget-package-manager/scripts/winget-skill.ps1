<#
.SYNOPSIS
    Winget Package Manager Skill - Main Entry Point

.DESCRIPTION
    Controlled Windows package management skill using winget.
    Returns structured JSON for all operations.

.EXAMPLE
    .\winget-skill.ps1 -Action search -Query "Chrome"
.EXAMPLE
    .\winget-skill.ps1 -Action install -PackageId Microsoft.VisualStudioCode -Exact
.EXAMPLE
    .\winget-skill.ps1 -Action list-upgrades
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('search', 'show', 'download', 'install', 'upgrade', 'uninstall', 'list-upgrades')]
    [string]$Action,

    [string]$Query,

    [string]$PackageId,

    [ValidateSet('winget', 'msstore')]
    [string]$Source = "winget",

    [string]$DownloadPath,

    [switch]$Exact
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import wrapper functions
. (Join-Path $PSScriptRoot "winget-wrapper.ps1")

# --- Helpers ---

function Write-JsonOutput {
    param([hashtable]$Data)
    $Data | ConvertTo-Json -Depth 8 -Compress
}

function Exit-WithError {
    param([string]$Message, [int]$Code = 1)
    Write-JsonOutput ([ordered]@{ success = $false; action = $Action; error = $Message })
    exit $Code
}

# --- Validate winget ---

$wingetStatus = Test-WingetAvailable
if (-not $wingetStatus.Available) {
    Exit-WithError "winget is not installed or not in PATH. Install from https://aka.ms/getwinget"
}

# --- Execute ---

try {
    $output = switch ($Action) {
        'search' {
            if (-not $Query) { Exit-WithError "Query parameter is required for search" }
            Search-WingetPackage -Query $Query -Source $Source
        }
        'show' {
            if (-not $PackageId) { Exit-WithError "PackageId parameter is required for show" }
            Show-WingetPackage -PackageId $PackageId -Source $Source
        }
        'download' {
            if (-not $PackageId) { Exit-WithError "PackageId parameter is required for download" }
            if (-not $DownloadPath) { Exit-WithError "DownloadPath parameter is required for download" }
            Save-WingetPackage -PackageId $PackageId -DownloadPath $DownloadPath -Source $Source
        }
        'install' {
            if (-not $PackageId) { Exit-WithError "PackageId parameter is required for install" }
            Install-WingetPackage -PackageId $PackageId -Source $Source -Exact:$Exact
        }
        'upgrade' {
            if (-not $PackageId) { Exit-WithError "PackageId parameter is required for upgrade" }
            Update-WingetPackage -PackageId $PackageId -Source $Source -Exact:$Exact
        }
        'uninstall' {
            if (-not $PackageId) { Exit-WithError "PackageId parameter is required for uninstall" }
            Uninstall-WingetPackage -PackageId $PackageId -Source $Source
        }
        'list-upgrades' {
            Get-WingetUpgradeablePackages -Source $Source
        }
    }

    Write-JsonOutput $output
    exit $(if ($output.success) { 0 } else { 1 })
}
catch {
    Write-JsonOutput ([ordered]@{
        success = $false
        action  = $Action
        error   = $_.Exception.Message
        summary = "Unhandled exception"
    })
    exit 1
}

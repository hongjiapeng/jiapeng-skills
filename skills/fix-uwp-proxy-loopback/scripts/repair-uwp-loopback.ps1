[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$PackageNames = @(
        'Microsoft.WindowsStore',
        'Microsoft.StorePurchaseApp',
        'Microsoft.DesktopAppInstaller',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.GamingServices',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.Xbox.TCUI'
    ),
    [switch]$ResetStore,
    [switch]$ImportWinHttpProxy,
    [switch]$ResetWinHttpProxy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Get-CurrentUserProxy {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    if (-not (Test-Path $path)) {
        return [pscustomobject]@{
            ProxyEnable   = $null
            ProxyServer   = $null
            AutoConfigURL = $null
        }
    }

    $settings = Get-ItemProperty $path
    $proxyEnable = if ($settings.PSObject.Properties.Name -contains 'ProxyEnable') { $settings.ProxyEnable } else { $null }
    $proxyServer = if ($settings.PSObject.Properties.Name -contains 'ProxyServer') { $settings.ProxyServer } else { $null }
    $autoConfigUrl = if ($settings.PSObject.Properties.Name -contains 'AutoConfigURL') { $settings.AutoConfigURL } else { $null }

    [pscustomobject]@{
        ProxyEnable   = $proxyEnable
        ProxyServer   = $proxyServer
        AutoConfigURL = $autoConfigUrl
    }
}

function Add-LoopbackExemption {
    param([Parameter(Mandatory = $true)][string]$PackageFamilyName)

    $target = "LoopbackExempt $PackageFamilyName"
    if ($PSCmdlet.ShouldProcess($target, 'Add UWP loopback exemption')) {
        $output = & "$env:WINDIR\System32\CheckNetIsolation.exe" LoopbackExempt -a "-n=$PackageFamilyName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to add $PackageFamilyName. Output: $output"
            return $false
        }

        Write-Host "Added or already present: $PackageFamilyName" -ForegroundColor Green
        return $true
    }

    return $false
}

Write-Section 'Detected Appx packages'
$packages = foreach ($name in $PackageNames) {
    Get-AppxPackage -Name $name -ErrorAction SilentlyContinue
}

if (-not $packages) {
    Write-Warning 'No target Appx packages were found for the current user.'
} else {
    $packages |
        Sort-Object Name -Unique |
        Select-Object Name, PackageFamilyName, Status |
        Format-Table -AutoSize
}

Write-Section 'Adding loopback exemptions'
$added = 0
foreach ($package in ($packages | Sort-Object PackageFamilyName -Unique)) {
    if ([string]::IsNullOrWhiteSpace($package.PackageFamilyName)) {
        continue
    }

    if (Add-LoopbackExemption -PackageFamilyName $package.PackageFamilyName) {
        $added++
    }
}

if ($added -eq 0 -and $packages) {
    Write-Host 'No exemptions were added. Re-run without -WhatIf if this was a dry run.' -ForegroundColor Yellow
}

if ($ResetStore) {
    Write-Section 'Resetting Microsoft Store cache'
    $storeProcesses = @('WinStore.App', 'WinStore.Mobile', 'MicrosoftStore')
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $storeProcesses -contains $_.ProcessName } |
        Stop-Process -Force

    Start-Process -FilePath 'wsreset.exe'
    Write-Host 'Started wsreset.exe. Microsoft Store may reopen automatically.' -ForegroundColor Green
}

if ($ImportWinHttpProxy) {
    Write-Section 'Importing WinHTTP proxy from current user settings'
    if ($PSCmdlet.ShouldProcess('WinHTTP proxy', 'Import from current user/IE proxy settings')) {
        netsh winhttp import proxy source=ie
    }
}

if ($ResetWinHttpProxy) {
    Write-Section 'Resetting WinHTTP proxy'
    if ($PSCmdlet.ShouldProcess('WinHTTP proxy', 'Reset to direct access')) {
        netsh winhttp reset proxy
    }
}

Write-Section 'Current loopback exemptions'
& "$env:WINDIR\System32\CheckNetIsolation.exe" LoopbackExempt -s

Write-Section 'Current user proxy'
Get-CurrentUserProxy | Format-List

Write-Section 'Current WinHTTP proxy'
netsh winhttp show proxy

Write-Host ''
Write-Host 'Done. Reopen the affected UWP app and test again.' -ForegroundColor Green

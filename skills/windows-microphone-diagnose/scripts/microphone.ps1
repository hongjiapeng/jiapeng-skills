[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('diagnose', 'list', 'enable', 'set-default', 'unmute', 'set-volume', 'probe')]
    [string]$Action = 'diagnose',
    [string]$DeviceId,
    [ValidateSet('all', 'console', 'multimedia', 'communications')]
    [string]$Role = 'all',
    [ValidateRange(0, 100)] [double]$Volume,
    [ValidateRange(1, 30)] [int]$Seconds = 5
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$taskResult = [ordered]@{ schemaVersion = 1; action = $Action; success = $false; changed = $false; data = $null; before = $null; after = $null; steps = @(); error = $null }

function Get-EndpointSnapshot {
    $taskNative = [PersonalMicrophone.Audio]::Read()
    $taskEndpoints = @()
    foreach ($taskEndpoint in $taskNative.endpoints) {
        $taskName = $null; $taskInterface = $null; $taskNameError = $null
        try { if ($taskEndpoint.id -match '\.({[0-9a-fA-F-]+})$') {
            $taskPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\' + $Matches[1] + '\Properties'
            if (Test-Path -LiteralPath $taskPath) {
                $taskProperties = Get-ItemProperty -LiteralPath $taskPath
                $taskDescription = $taskProperties.PSObject.Properties['{a45c254e-df1c-4efd-8020-67d146a850e0},2']
                $taskInterfaceProperty = $taskProperties.PSObject.Properties['{b3f8fa53-0004-438e-9003-51a46e139bfc},6']
                if ($null -ne $taskDescription) { $taskName = $taskDescription.Value }
                if ($null -ne $taskInterfaceProperty) { $taskInterface = $taskInterfaceProperty.Value }
            }
        } } catch { $taskNameError = $_.Exception.Message }
        $taskEndpoints += [pscustomobject]@{
            id = $taskEndpoint.id; name = $taskName; deviceInterface = $taskInterface
            state = $taskEndpoint.state; stateLabel = $taskEndpoint.stateLabel
            volumePercent = $taskEndpoint.volumePercent; muted = $taskEndpoint.muted; controlError = $taskEndpoint.controlError; nameReadError = $taskNameError
            virtualHint = (($taskName + ' ' + $taskInterface) -match '(?i)virtual|ToDesk|VB-Audio|Voicemeeter|CABLE|虚拟')
        }
    }
    [pscustomobject]@{ endpoints = $taskEndpoints; defaults = @($taskNative.defaults) }
}

function Read-RegistryValue([string]$Path, [string]$Name) {
    try {
        $taskItem = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        $taskProperty = $taskItem.PSObject.Properties[$Name]
        if ($null -eq $taskProperty) { return [pscustomobject]@{ path = $Path; name = $Name; value = $null; status = 'unknown'; error = $null } }
        [pscustomobject]@{ path = $Path; name = $Name; value = $taskProperty.Value; status = 'read'; error = $null }
    } catch { [pscustomobject]@{ path = $Path; name = $Name; value = $null; status = 'unknown'; error = $_.Exception.Message } }
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'This skill requires Windows.' }
    if ($null -eq ('PersonalMicrophone.Audio' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'CoreAudio.cs') -ErrorAction Stop }
    $taskBefore = Get-EndpointSnapshot
    if ($Action -in @('diagnose', 'list')) {
        $taskResult.data = $taskBefore
        if ($Action -eq 'diagnose') {
            $taskServices = @(Get-Service -Name Audiosrv, AudioEndpointBuilder | ForEach-Object {
                [pscustomobject]@{ name = $_.Name; status = [string]$_.Status; startType = [string]$_.StartType }
            })
            $taskPrivacy = @(
                (Read-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value')
                (Read-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value')
                (Read-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged' 'Value')
                (Read-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessMicrophone')
            )
            $taskPnp = @(); $taskPnpError = $null
            try {
                $taskPnp = @(Get-PnpDevice -Class MEDIA, AudioEndpoint, System | Where-Object {
                    $_.Class -in @('MEDIA', 'AudioEndpoint') -or $_.FriendlyName -match 'Smart Sound|智音|Audio|音频'
                } | Select-Object Status, Class, FriendlyName, InstanceId)
            } catch { $taskPnpError = $_.Exception.Message }
            $taskResult.data = [pscustomobject]@{
                endpoints = $taskBefore.endpoints; defaults = $taskBefore.defaults
                services = $taskServices; privacy = $taskPrivacy; pnpDevices = $taskPnp; pnpQueryError = $taskPnpError
            }
        }
        $taskResult.success = $true
    } else {
        if ([string]::IsNullOrWhiteSpace($DeviceId)) { throw '-DeviceId is required; use an exact capture endpoint ID from diagnose/list.' }
        $taskTargets = @($taskBefore.endpoints | Where-Object { $_.id -eq $DeviceId })
        if ($taskTargets.Count -ne 1) { throw 'Target is not a unique enumerated capture endpoint. Run diagnose/list again.' }
        $taskTarget = $taskTargets[0]
        if ($Action -eq 'set-volume' -and !$PSBoundParameters.ContainsKey('Volume')) { throw '-Volume is required for set-volume.' }
        if ($Action -eq 'enable') {
            if ($taskTarget.stateLabel -notin @('active', 'disabled')) { throw 'Target is disconnected/not present. Check connection or driver first.' }
        } elseif ($taskTarget.stateLabel -ne 'active') { throw 'Target must be active for this action.' }
        $taskResult.before = $taskBefore
        if ($Action -eq 'probe') {
            $taskResult.data = [PersonalMicrophone.Audio]::Probe($DeviceId, $Seconds)
            $taskResult.success = $true
        } elseif ($WhatIfPreference) {
            # JSON-only preview, with no calls to native setters.
            $taskResult.data = [pscustomobject]@{ preview = $true; target = $taskTarget; role = $Role; volume = $(if ($Action -eq 'set-volume') { $Volume } else { $null }) }
            $taskResult.after = $taskBefore; $taskResult.success = $true
        } elseif ($PSCmdlet.ShouldProcess($DeviceId, $Action)) {
            $taskRoles = @('console', 'multimedia', 'communications')
            if ($Action -eq 'set-default') {
                foreach ($taskRoleIndex in 0..2) {
                    if ($Role -eq 'all' -or $Role -eq $taskRoles[$taskRoleIndex]) {
                        $taskNativeHr = [PersonalMicrophone.Audio]::SetDefault($DeviceId, $taskRoleIndex)
                        $taskResult.steps += [pscustomobject]@{ operation = 'set-default'; role = $taskRoles[$taskRoleIndex]; hresult = ('0x{0:X8}' -f $taskNativeHr) }
                    }
                }
            } elseif ($Action -eq 'enable') { $taskNativeHr = [PersonalMicrophone.Audio]::Enable($DeviceId) }
            elseif ($Action -eq 'unmute') { $taskNativeHr = [PersonalMicrophone.Audio]::SetInput($DeviceId, $true, 0) }
            elseif ($Action -eq 'set-volume') { $taskNativeHr = [PersonalMicrophone.Audio]::SetInput($DeviceId, $false, [single]$Volume) }
            if ($Action -ne 'set-default') { $taskResult.steps += [pscustomobject]@{ operation = $Action; hresult = ('0x{0:X8}' -f $taskNativeHr) } }
            $taskVerified = $false
            for ($taskAttempt = 0; $taskAttempt -lt 10; $taskAttempt++) {
                if ($taskAttempt -gt 0) { Start-Sleep -Milliseconds 200 }
                $taskResult.after = Get-EndpointSnapshot
                $taskAfterTarget = @($taskResult.after.endpoints | Where-Object { $_.id -eq $DeviceId })
                if ($taskAfterTarget.Count -eq 1) {
                    if ($Action -eq 'enable') { $taskVerified = $taskAfterTarget[0].stateLabel -eq 'active' }
                    elseif ($Action -eq 'unmute') { $taskVerified = $null -ne $taskAfterTarget[0].muted -and $taskAfterTarget[0].muted -eq $false }
                    elseif ($Action -eq 'set-volume') { $taskVerified = $null -ne $taskAfterTarget[0].volumePercent -and [Math]::Abs($taskAfterTarget[0].volumePercent - $Volume) -lt 1 }
                    else {
                        $taskDefaults = @($taskResult.after.defaults | Where-Object { $Role -eq 'all' -or $_.role -eq $Role })
                        $taskCount = $(if ($Role -eq 'all') { 3 } else { 1 })
                        $taskVerified = $taskDefaults.Count -eq $taskCount -and @($taskDefaults | Where-Object { $_.id -ne $DeviceId }).Count -eq 0
                    }
                }
                if ($taskVerified) { break }
            }
            $taskResult.changed = (ConvertTo-Json -InputObject $taskBefore -Depth 8 -Compress) -ne (ConvertTo-Json -InputObject $taskResult.after -Depth 8 -Compress)
            if (!$taskVerified) { throw 'Native call succeeded, but the requested resulting state was not verified.' }
            $taskResult.success = $true
        } else {
            $taskResult.data = [pscustomobject]@{ skipped = $true }; $taskResult.after = $taskBefore; $taskResult.success = $true
        }
    }
} catch {
    $taskException = $_.Exception
    while ($null -ne $taskException.InnerException) { $taskException = $taskException.InnerException }
    $taskResult.error = [pscustomobject]@{ message = $taskException.Message; hresult = ('0x{0:X8}' -f $taskException.HResult) }
    if ($null -ne $taskResult.before) {
        try {
            $taskResult.after = Get-EndpointSnapshot
            $taskResult.changed = (ConvertTo-Json -InputObject $taskResult.before -Depth 8 -Compress) -ne (ConvertTo-Json -InputObject $taskResult.after -Depth 8 -Compress)
        } catch { $taskResult.after = $null; $taskResult.changed = $null }
    }
}
$taskResult | ConvertTo-Json -Depth 12
if (!$taskResult.success) { exit 1 }

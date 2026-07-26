[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Invoke-WindowsJunkCleaner.ps1'
$enginePath = if ($PSVersionTable.PSEdition -eq 'Core') {
    (Get-Process -Id $PID).Path
}
else {
    Join-Path $PSHOME 'powershell.exe'
}
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clean-windows-junk-test-' + [guid]::NewGuid().ToString('N'))
$oldTestRoot = [Environment]::GetEnvironmentVariable('CJW_TEST_ROOT', 'Process')

try {
    $cache = Join-Path $testRoot 'DemoApp\Cache'
    [void](New-Item -ItemType Directory -Path $cache -Force)
    Set-Content -LiteralPath (Join-Path $cache 'delete.tmp') -Value 'delete me' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $cache 'keep.tmp') -Value 'keep me' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $cache 'ignore.log') -Value 'ignore me' -Encoding utf8
    $wildcardCache = Join-Path $testRoot 'DemoApp-Beta\Cache'
    [void](New-Item -ItemType Directory -Path $wildcardCache -Force)
    Set-Content -LiteralPath (Join-Path $wildcardCache 'wildcard.tmp') -Value 'wildcard me' -Encoding utf8
    [Environment]::SetEnvironmentVariable('CJW_TEST_ROOT', $testRoot, 'Process')

    $rulesPath = Join-Path $testRoot 'Winapp2.ini'
    @'
; Version: test-1
; Winapp2.ini test fixture
[Demo Cache *]
Default=True
DetectFile=%CJW_TEST_ROOT%\DemoApp
FileKey1=%CJW_TEST_ROOT%\DemoApp\Cache|*.tmp|RECURSE
ExcludeKey1=FILE|%CJW_TEST_ROOT%\DemoApp\Cache|keep.tmp

[Risky Demo *]
Default=False
Warning=Test warning
DetectFile=%CJW_TEST_ROOT%\DemoApp
FileKey1=%CJW_TEST_ROOT%\DemoApp\Cache|*.log

[Blocked Root Demo *]
Default=True
DetectFile=%CJW_TEST_ROOT%\DemoApp
FileKey1=%SystemDrive%\|*.tmp

[Wildcard Cache *]
Default=True
DetectFile=%CJW_TEST_ROOT%\DemoApp-*
FileKey1=%CJW_TEST_ROOT%\DemoApp-*\Cache|*.tmp
'@ | Set-Content -LiteralPath $rulesPath -Encoding utf8

    $planPath = Join-Path $testRoot 'plan.json'
    $validationText = & $enginePath -NoProfile -File $scriptPath -Action ValidateRules -RulesPath $rulesPath
    if ($LASTEXITCODE -ne 0) {
        throw "ValidateRules failed: $validationText"
    }
    $validation = $validationText | ConvertFrom-Json
    if (-not $validation.success -or $validation.entry_count -ne 4) {
        throw 'ValidateRules returned an unexpected result.'
    }

    $scanText = & $enginePath -NoProfile -File $scriptPath -Action Scan -RulesPath $rulesPath -Entry 'Demo Cache' -PlanPath $planPath
    if ($LASTEXITCODE -ne 0) {
        throw "Scan failed: $scanText"
    }
    $scan = $scanText | ConvertFrom-Json
    if (-not $scan.success -or $scan.file_count -ne 1) {
        throw 'Scan did not produce the expected single-file plan.'
    }

    $wrongText = & $enginePath -NoProfile -File $scriptPath -Action Clean -PlanPath $planPath -ConfirmPlanId 'sha256:wrong'
    if ($LASTEXITCODE -eq 0) {
        throw 'Clean unexpectedly accepted an incorrect plan ID.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cache 'delete.tmp'))) {
        throw 'Incorrect confirmation deleted a file.'
    }

    $cleanText = & $enginePath -NoProfile -File $scriptPath -Action Clean -PlanPath $planPath -ConfirmPlanId $scan.plan_id
    if ($LASTEXITCODE -ne 0) {
        throw "Clean failed: $cleanText"
    }
    $clean = $cleanText | ConvertFrom-Json
    if (-not $clean.success -or $clean.deleted_count -ne 1) {
        throw "Clean returned an unexpected result: $cleanText"
    }
    if (Test-Path -LiteralPath (Join-Path $cache 'delete.tmp')) {
        throw 'Planned file was not deleted.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cache 'keep.tmp'))) {
        throw 'Excluded file was deleted.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cache 'ignore.log'))) {
        throw 'Non-matching file was deleted.'
    }

    $riskyPlanPath = Join-Path $testRoot 'risky-plan.json'
    $riskyScanText = & $enginePath -NoProfile -File $scriptPath -Action Scan -RulesPath $rulesPath -Entry 'Risky Demo' -PlanPath $riskyPlanPath
    if ($LASTEXITCODE -ne 0) {
        throw "Risky scan failed: $riskyScanText"
    }
    $riskyScan = $riskyScanText | ConvertFrom-Json
    if (-not $riskyScan.requires_allow_risky -or $riskyScan.file_count -ne 1) {
        throw "Risky scan did not require explicit risk acceptance: $riskyScanText"
    }

    $blockedRiskText = & $enginePath -NoProfile -File $scriptPath -Action Clean -PlanPath $riskyPlanPath -ConfirmPlanId $riskyScan.plan_id
    if ($LASTEXITCODE -eq 0) {
        throw 'Risky clean unexpectedly ran without -AllowRisky.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cache 'ignore.log'))) {
        throw 'Risky clean deleted a file without risk acceptance.'
    }

    $riskyCleanText = & $enginePath -NoProfile -File $scriptPath -Action Clean -PlanPath $riskyPlanPath -ConfirmPlanId $riskyScan.plan_id -AllowRisky
    if ($LASTEXITCODE -ne 0) {
        throw "Risky clean with explicit acceptance failed: $riskyCleanText"
    }
    $riskyClean = $riskyCleanText | ConvertFrom-Json
    if (-not $riskyClean.success -or $riskyClean.deleted_count -ne 1) {
        throw 'Risky clean returned an unexpected result.'
    }

    $blockedPlanPath = Join-Path $testRoot 'blocked-plan.json'
    $blockedScanText = & $enginePath -NoProfile -File $scriptPath -Action Scan -RulesPath $rulesPath -Entry 'Blocked Root Demo' -PlanPath $blockedPlanPath
    if ($LASTEXITCODE -ne 0) {
        throw "Blocked-root scan failed: $blockedScanText"
    }
    $blockedScan = $blockedScanText | ConvertFrom-Json
    if ($blockedScan.file_count -ne 0 -or $blockedScan.skipped_rules.Count -ne 1) {
        throw 'Unsafe root rule was not blocked as expected.'
    }

    $wildcardPlanPath = Join-Path $testRoot 'wildcard-plan.json'
    $wildcardScanText = & $enginePath -NoProfile -File $scriptPath -Action Scan -RulesPath $rulesPath -Entry 'Wildcard Cache' -PlanPath $wildcardPlanPath
    if ($LASTEXITCODE -ne 0) {
        throw "Wildcard scan failed: $wildcardScanText"
    }
    $wildcardScan = $wildcardScanText | ConvertFrom-Json
    if ($wildcardScan.file_count -ne 1 -or $wildcardScan.skipped_rules.Count -ne 0) {
        throw "Wildcard directory rule was not resolved as expected: $wildcardScanText"
    }

    $winapp3Path = Join-Path $testRoot 'Winapp3.ini'
    @'
; Winapp3.ini advanced rules
[Dangerous Demo *]
DetectFile=%CJW_TEST_ROOT%\DemoApp
FileKey1=%CJW_TEST_ROOT%\DemoApp\Cache|*
'@ | Set-Content -LiteralPath $winapp3Path -Encoding utf8
    $winapp3PlanPath = Join-Path $testRoot 'winapp3-plan.json'
    $winapp3Text = & $enginePath -NoProfile -File $scriptPath -Action Scan -RulesPath $winapp3Path -Entry 'Dangerous Demo' -PlanPath $winapp3PlanPath
    if ($LASTEXITCODE -eq 0) {
        throw 'Winapp3 rules were not rejected.'
    }

    [ordered]@{
        success = $true
        engine = "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
        validation_entry_count = $validation.entry_count
        planned_file_count = $scan.file_count
        deleted_count = $clean.deleted_count
        excluded_file_preserved = $true
        incorrect_confirmation_rejected = $true
        risky_confirmation_enforced = $true
        unsafe_root_blocked = $true
        wildcard_path_supported = $true
        winapp3_rejected = $true
    } | ConvertTo-Json
}
finally {
    [Environment]::SetEnvironmentVariable('CJW_TEST_ROOT', $oldTestRoot, 'Process')
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolved) -like 'clean-windows-junk-test-*' -and
        (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

[CmdletBinding()]
param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param(
        [Parameter(Mandatory)]
        [string]$Status,
        [string]$GhPath,
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$Message
    )

    [pscustomobject]@{
        status  = $Status
        ghPath  = $GhPath
        version = $Version
        message = $Message
    } | ConvertTo-Json -Compress
}

function Find-Gh {
    $command = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

$ghPath = Find-Gh

if (-not $ghPath -and -not $Install) {
    Write-Result -Status 'missing' -Message 'GitHub CLI is not installed or could not be found. Rerun with -Install.'
    exit 0
}

if (-not $ghPath) {
    $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $winget) {
        Write-Result -Status 'unsupported' -Message 'WinGet is unavailable. Install GitHub CLI manually, then rerun this script.'
        exit 0
    }

    try {
        $output = & $winget.Source install --id GitHub.cli --exact --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Result -Status 'install-failed' -Message (($output | Out-String).Trim())
            exit 0
        }
    }
    catch {
        Write-Result -Status 'install-failed' -Message $_.Exception.Message
        exit 0
    }

    $ghPath = Find-Gh
    if (-not $ghPath) {
        Write-Result -Status 'install-failed' -Message 'WinGet completed, but gh.exe could not be located. Open a new terminal and rerun the preflight.'
        exit 0
    }
}

try {
    $versionOutput = & $ghPath --version 2>&1
    $versionExitCode = $LASTEXITCODE
    $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
    if ($versionExitCode -ne 0) {
        throw ($versionOutput | Out-String).Trim()
    }
}
catch {
    Write-Result -Status 'install-failed' -GhPath $ghPath -Message "gh was found but could not run: $($_.Exception.Message)"
    exit 0
}

$null = & $ghPath auth status --hostname github.com 2>&1
$authExitCode = $LASTEXITCODE
if ($authExitCode -ne 0) {
    Write-Result -Status 'needs-login' -GhPath $ghPath -Version $version -Message 'Run: gh auth login --hostname github.com --git-protocol https --web'
    exit 0
}

Write-Result -Status 'ready' -GhPath $ghPath -Version $version -Message 'GitHub CLI is installed and authenticated for github.com.'

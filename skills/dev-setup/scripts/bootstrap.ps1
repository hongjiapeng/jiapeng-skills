#Requires -Version 5.1

<#
.SYNOPSIS
Previews or applies a configuration-driven Windows development environment.

.DESCRIPTION
Reads machine-specific values from a PowerShell data file. The script performs a
dry run unless -Execute is supplied. It never stores names, email addresses,
repository URLs, or machine-specific paths in this public template.

.PARAMETER ConfigPath
Path to a PowerShell data file based on assets/config.example.psd1.

.PARAMETER Step
One or more stages to run: All, Directories, Git, or Repositories.

.PARAMETER RootPath
Optional command-line override for RootPath in the configuration file.

.PARAMETER Execute
Applies the planned changes. Without this switch, the script only previews them.

.EXAMPLE
.\bootstrap.ps1 -ConfigPath $PrivateConfigPath

.EXAMPLE
.\bootstrap.ps1 -ConfigPath $PrivateConfigPath -Step Directories -Execute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath,

    [ValidateSet("All", "Directories", "Git", "Repositories")]
    [string[]]$Step = @("All"),

    [string]$RootPath,

    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "  -> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [SKIP] $Message" -ForegroundColor DarkGray
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Get-OptionalValue {
    param(
        [hashtable]$Table,
        [string]$Key,
        $DefaultValue = $null
    )

    if ($null -ne $Table -and $Table.ContainsKey($Key)) {
        return $Table[$Key]
    }

    return $DefaultValue
}

function Resolve-ConfiguredPath {
    param(
        [string]$Value,
        [string]$BasePath,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label must be configured."
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Value)
    if (-not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path $BasePath $expanded
    }

    return [IO.Path]::GetFullPath($expanded)
}

function Resolve-ChildPath {
    param(
        [string]$BasePath,
        [string]$RelativePath,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "$Label must be a non-empty relative path."
    }

    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "$Label must be relative to '$BasePath'."
    }

    $resolvedBase = [IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $resolvedChild = [IO.Path]::GetFullPath((Join-Path $resolvedBase $RelativePath))
    $requiredPrefix = "$resolvedBase\"

    if (-not $resolvedChild.StartsWith(
            $requiredPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "$Label resolves outside '$resolvedBase'."
    }

    return $resolvedChild
}

function Convert-ToGitPath {
    param([string]$Path)
    return ([IO.Path]::GetFullPath($Path).TrimEnd("\", "/").Replace("\", "/") + "/")
}

function Get-RepositoryName {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw "Each repository entry must define a non-empty Url."
    }

    $normalized = $Url.Trim().TrimEnd("/") -replace "\.git$", ""
    $match = [regex]::Match($normalized, "([^/:]+)$")
    if (-not $match.Success) {
        throw "Unable to derive a repository name from '$Url'."
    }

    $name = $match.Groups[1].Value
    if ($name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "Repository name '$name' contains invalid file-name characters."
    }

    return $name
}

function Assert-Identity {
    param(
        [hashtable]$Identity,
        [string]$Label
    )

    $name = [string](Get-OptionalValue -Table $Identity -Key "Name" -DefaultValue "")
    $email = [string](Get-OptionalValue -Table $Identity -Key "Email" -DefaultValue "")
    $hasName = -not [string]::IsNullOrWhiteSpace($name)
    $hasEmail = -not [string]::IsNullOrWhiteSpace($email)

    if ($hasName -xor $hasEmail) {
        throw "$Label Git identity must provide both Name and Email."
    }

    return ($hasName -and $hasEmail)
}

function Invoke-Git {
    param(
        [string]$GitExecutable,
        [string[]]$Arguments
    )

    & $GitExecutable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed with exit code $LASTEXITCODE."
    }
}

$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$configDirectory = Split-Path -Parent $resolvedConfigPath
$config = Import-PowerShellDataFile -LiteralPath $resolvedConfigPath

if (-not ($config -is [hashtable])) {
    throw "The configuration file must return a hashtable."
}

$configuredRootPath = [string](
    Get-OptionalValue -Table $config -Key "RootPath" -DefaultValue ""
)
if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
    $configuredRootPath = $RootPath
}

$resolvedRootPath = Resolve-ConfiguredPath `
    -Value $configuredRootPath `
    -BasePath $configDirectory `
    -Label "RootPath"

$directories = Get-OptionalValue -Table $config -Key "Directories"
if (-not ($directories -is [hashtable])) {
    throw "Directories must be configured as a hashtable."
}

$workPath = Resolve-ChildPath `
    -BasePath $resolvedRootPath `
    -RelativePath ([string](Get-OptionalValue -Table $directories -Key "Work" -DefaultValue "")) `
    -Label "Directories.Work"

$personalPath = Resolve-ChildPath `
    -BasePath $resolvedRootPath `
    -RelativePath ([string](Get-OptionalValue -Table $directories -Key "Personal" -DefaultValue "")) `
    -Label "Directories.Personal"

$additionalDirectories = @(
    Get-OptionalValue -Table $directories -Key "Additional" -DefaultValue @()
)
$personalGroups = @(
    Get-OptionalValue -Table $directories -Key "PersonalGroups" -DefaultValue @()
)

$runAll = $Step -contains "All"
$runDirectories = $runAll -or $Step -contains "Directories"
$runGit = $runAll -or $Step -contains "Git"
$runRepositories = $runAll -or $Step -contains "Repositories"
$dryRun = -not $Execute

Write-Host ""
Write-Host "DEV SETUP - $(if ($dryRun) { 'DRY RUN' } else { 'APPLYING CHANGES' })" `
    -ForegroundColor $(if ($dryRun) { "Magenta" } else { "Green" })
Write-Host "Configuration: $resolvedConfigPath"
Write-Host "Root: $resolvedRootPath"

if ($runDirectories) {
    Write-Host ""
    Write-Host "Step: Directories" -ForegroundColor White

    $plannedDirectories = @($workPath, $personalPath)
    foreach ($relativePath in $additionalDirectories) {
        $plannedDirectories += Resolve-ChildPath `
            -BasePath $resolvedRootPath `
            -RelativePath ([string]$relativePath) `
            -Label "Directories.Additional"
    }
    foreach ($relativePath in $personalGroups) {
        $plannedDirectories += Resolve-ChildPath `
            -BasePath $personalPath `
            -RelativePath ([string]$relativePath) `
            -Label "Directories.PersonalGroups"
    }

    foreach ($directory in $plannedDirectories | Select-Object -Unique) {
        if (Test-Path -LiteralPath $directory) {
            Write-Skip "$directory already exists"
            continue
        }

        Write-Step "Create $directory"
        if (-not $dryRun) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Write-Success "Created $directory"
        }
    }
}

if ($runGit) {
    Write-Host ""
    Write-Host "Step: Git identities" -ForegroundColor White

    $gitConfig = Get-OptionalValue -Table $config -Key "Git"
    if (-not ($gitConfig -is [hashtable])) {
        throw "Git must be configured as a hashtable when the Git step is selected."
    }

    $personalIdentity = Get-OptionalValue -Table $gitConfig -Key "Personal" -DefaultValue @{}
    $workIdentity = Get-OptionalValue -Table $gitConfig -Key "Work" -DefaultValue @{}
    if (-not ($personalIdentity -is [hashtable]) -or -not ($workIdentity -is [hashtable])) {
        throw "Git.Personal and Git.Work must be hashtables."
    }

    $hasPersonalIdentity = Assert-Identity -Identity $personalIdentity -Label "Personal"
    $hasWorkIdentity = Assert-Identity -Identity $workIdentity -Label "Work"
    if (-not $hasPersonalIdentity -and -not $hasWorkIdentity) {
        throw "Configure at least one complete Git identity before running the Git step."
    }

    $gitStorageValue = [string](
        Get-OptionalValue -Table $gitConfig -Key "ConfigDirectory" -DefaultValue ""
    )
    if ([string]::IsNullOrWhiteSpace($gitStorageValue)) {
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $gitStoragePath = Join-Path $localAppData "dev-setup"
    } else {
        $gitStoragePath = Resolve-ConfiguredPath `
            -Value $gitStorageValue `
            -BasePath $configDirectory `
            -Label "Git.ConfigDirectory"
    }

    $personalConfigPath = Join-Path $gitStoragePath "gitconfig-personal"
    $workConfigPath = Join-Path $gitStoragePath "gitconfig-work"
    $plannedIdentities = @()

    if ($hasPersonalIdentity) {
        $plannedIdentities += @{
            Label = "Personal"
            Root = $personalPath
            ConfigPath = $personalConfigPath
            Identity = $personalIdentity
        }
    }
    if ($hasWorkIdentity) {
        $plannedIdentities += @{
            Label = "Work"
            Root = $workPath
            ConfigPath = $workConfigPath
            Identity = $workIdentity
        }
    }

    foreach ($entry in $plannedIdentities) {
        Write-Step (
            "Configure {0} identity for repositories under {1}" -f
            $entry.Label,
            $entry.Root
        )
    }

    if (-not $dryRun) {
        $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop
        New-Item -ItemType Directory -Path $gitStoragePath -Force | Out-Null

        foreach ($entry in $plannedIdentities) {
            Invoke-Git -GitExecutable $gitCommand.Source -Arguments @(
                "config",
                "--file",
                $entry.ConfigPath,
                "user.name",
                [string]$entry.Identity["Name"]
            )
            Invoke-Git -GitExecutable $gitCommand.Source -Arguments @(
                "config",
                "--file",
                $entry.ConfigPath,
                "user.email",
                [string]$entry.Identity["Email"]
            )

            $includeCondition = Convert-ToGitPath -Path $entry.Root
            $includeKey = "includeIf.gitdir:$includeCondition.path"
            $includePath = $entry.ConfigPath.Replace("\", "/")
            Invoke-Git -GitExecutable $gitCommand.Source -Arguments @(
                "config",
                "--global",
                "--replace-all",
                $includeKey,
                $includePath
            )
            Write-Success "Configured $($entry.Label) Git identity"
        }
    }
}

if ($runRepositories) {
    Write-Host ""
    Write-Host "Step: Repositories" -ForegroundColor White

    $repositories = @(Get-OptionalValue -Table $config -Key "Repositories" -DefaultValue @())
    if ($repositories.Count -eq 0) {
        Write-Skip "No repositories configured"
    } else {
        $gitCommand = $null
        if (-not $dryRun) {
            $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop
        }

        $cloneFailures = 0
        foreach ($repository in $repositories) {
            if (-not ($repository -is [hashtable])) {
                throw "Each repository entry must be a hashtable."
            }

            $url = [string](Get-OptionalValue -Table $repository -Key "Url" -DefaultValue "")
            $destination = [string](
                Get-OptionalValue -Table $repository -Key "Destination" -DefaultValue ""
            )
            $repositoryName = Get-RepositoryName -Url $url
            $targetParent = $personalPath

            if (-not [string]::IsNullOrWhiteSpace($destination)) {
                $targetParent = Resolve-ChildPath `
                    -BasePath $personalPath `
                    -RelativePath $destination `
                    -Label "Repositories.Destination"
            }

            $clonePath = Resolve-ChildPath `
                -BasePath $targetParent `
                -RelativePath $repositoryName `
                -Label "Repository clone path"

            if (Test-Path -LiteralPath $clonePath) {
                Write-Skip "$clonePath already exists"
                continue
            }

            Write-Step "Clone $url to $clonePath"
            if ($dryRun) {
                continue
            }

            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            & $gitCommand.Source clone $url $clonePath
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Cloned $repositoryName"
            } else {
                Write-WarningMessage "Clone failed for $repositoryName"
                $cloneFailures++
            }
        }

        if ($cloneFailures -gt 0) {
            throw "$cloneFailures repository clone operation(s) failed."
        }
    }
}

Write-Host ""
if ($dryRun) {
    Write-Host "Dry run complete. Review the plan, then rerun with -Execute." `
        -ForegroundColor Magenta
} else {
    Write-Host "Development environment setup complete." -ForegroundColor Green
}

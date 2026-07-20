<#
.SYNOPSIS
    Generate and optionally validate a WinGet multi-file manifest from JSON.

.DESCRIPTION
    Supports common EXE, MSI, MSIX, portable, and ZIP/nested-installer releases.
    Downloads installers to calculate missing SHA256 values unless -Offline is used.

.PARAMETER ConfigPath
    UTF-8 JSON package configuration. See references/configuration.md.

.PARAMETER OutputDirectory
    Exact version directory to create, for example
    manifests\e\ExamplePublisher\ExampleTool\1.2.3.

.PARAMETER ManifestVersion
    WinGet manifest schema version. Defaults to 1.12.0.

.PARAMETER Force
    Allow generated manifest files to be overwritten.

.PARAMETER Validate
    Run winget validate against the output directory.

.PARAMETER Offline
    Prohibit installer downloads. Every installer must provide installerSha256.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ConfigPath,

    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,

    [string] $ManifestVersion = '1.12.0',

    [switch] $Force,

    [switch] $Validate,

    [switch] $Offline
)

$ErrorActionPreference = 'Stop'

function Test-Property {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-RequiredValue {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if (-not (Test-Property -Object $Object -Name $Name)) {
        throw "Missing required configuration field '$Name'."
    }

    $value = $Object.$Name
    if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
        throw "Configuration field '$Name' cannot be empty."
    }

    return $value
}

function ConvertTo-YamlScalar {
    param([AllowNull()] $Value)

    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }

    if ($null -eq $Value) {
        return 'null'
    }

    $text = [string] $Value
    return "'" + $text.Replace("'", "''") + "'"
}

function Add-OptionalScalar {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][System.Collections.Generic.List[string]] $Lines,
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $PropertyName,
        [Parameter(Mandatory = $true)][string] $YamlName
    )

    if (Test-Property -Object $Object -Name $PropertyName) {
        $value = $Object.$PropertyName
        if ($null -ne $value -and -not ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
            $Lines.Add("${YamlName}: $(ConvertTo-YamlScalar $value)")
        }
    }
}

function Add-StringList {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][System.Collections.Generic.List[string]] $Lines,
        [Parameter(Mandatory = $true)][string] $YamlName,
        [AllowNull()] $Values,
        [string] $Indent = ''
    )

    $items = @($Values) | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string] $_) }
    if ($items.Count -eq 0) {
        return
    }

    $Lines.Add("${Indent}${YamlName}:")
    foreach ($item in $items) {
        $Lines.Add("${Indent}- $(ConvertTo-YamlScalar $item)")
    }
}

function Add-InstallerSwitches {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][System.Collections.Generic.List[string]] $Lines,
        [Parameter(Mandatory = $true)] $Switches,
        [string] $Indent = ''
    )

    $switchMap = [ordered]@{
        silent = 'Silent'
        silentWithProgress = 'SilentWithProgress'
        interactive = 'Interactive'
        installLocation = 'InstallLocation'
        log = 'Log'
        upgrade = 'Upgrade'
        custom = 'Custom'
        repair = 'Repair'
    }
    $switchLines = [System.Collections.Generic.List[string]]::new()
    foreach ($propertyName in $switchMap.Keys) {
        if (Test-Property -Object $Switches -Name $propertyName) {
            $value = $Switches.$propertyName
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string] $value)) {
                $switchLines.Add("${Indent}  $($switchMap[$propertyName]): $(ConvertTo-YamlScalar $value)")
            }
        }
    }
    if ($switchLines.Count -gt 0) {
        $Lines.Add("${Indent}InstallerSwitches:")
        foreach ($line in $switchLines) {
            $Lines.Add($line)
        }
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]] $Lines
    )

    $content = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Get-InstallerSha256 {
    param(
        [Parameter(Mandatory = $true)] $Installer,
        [Parameter(Mandatory = $true)][bool] $IsOffline
    )

    if (Test-Property -Object $Installer -Name 'installerSha256') {
        $configuredHash = [string] $Installer.installerSha256
        if (-not [string]::IsNullOrWhiteSpace($configuredHash)) {
            $normalizedHash = $configuredHash.Trim().ToUpperInvariant()
            if ($normalizedHash -notmatch '^[0-9A-F]{64}$') {
                throw 'installerSha256 must be a 64-character hexadecimal SHA256 value.'
            }
            return $normalizedHash
        }
    }

    if ($IsOffline) {
        throw 'Offline mode requires installerSha256 for every installer.'
    }

    $installerUrl = [string] (Get-RequiredValue -Object $Installer -Name 'installerUrl')
    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Write-Host "Downloading installer to calculate SHA256: $installerUrl"
        Invoke-WebRequest -Uri $installerUrl -OutFile $temporaryFile -UseBasicParsing
        return (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash.ToUpperInvariant()
    }
    finally {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }
}

function Get-LocaleValue {
    param(
        [Parameter(Mandatory = $true)] $Locale,
        [Parameter(Mandatory = $true)] $Defaults,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if (Test-Property -Object $Locale -Name $Name) {
        return $Locale.$Name
    }
    if (Test-Property -Object $Defaults -Name $Name) {
        return $Defaults.$Name
    }
    return $null
}

$resolvedConfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigPath)
$resolvedOutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$configText = [System.IO.File]::ReadAllText($resolvedConfigPath, [System.Text.Encoding]::UTF8)
$config = $configText | ConvertFrom-Json

$packageIdentifier = [string] (Get-RequiredValue -Object $config -Name 'packageIdentifier')
$packageVersion = [string] (Get-RequiredValue -Object $config -Name 'packageVersion')
$defaultLocale = [string] (Get-RequiredValue -Object $config -Name 'defaultLocale')
$publisher = [string] (Get-RequiredValue -Object $config -Name 'publisher')
$packageName = [string] (Get-RequiredValue -Object $config -Name 'packageName')
$license = [string] (Get-RequiredValue -Object $config -Name 'license')
$shortDescription = [string] (Get-RequiredValue -Object $config -Name 'shortDescription')
$installerType = ([string] (Get-RequiredValue -Object $config -Name 'installerType')).ToLowerInvariant()
$installers = @(Get-RequiredValue -Object $config -Name 'installers')

if ($packageIdentifier -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{1,127}$') {
    throw "Invalid packageIdentifier '$packageIdentifier'."
}
if ($packageVersion -match '[\\/]') {
    throw "Invalid packageVersion '$packageVersion'."
}
if ($installers.Count -eq 0) {
    throw 'At least one installer is required.'
}

$nestedInstallerType = $null
if (Test-Property -Object $config -Name 'nestedInstallerType') {
    $nestedInstallerType = ([string] $config.nestedInstallerType).ToLowerInvariant()
}
$isPortable = $installerType -eq 'portable' -or ($installerType -eq 'zip' -and $nestedInstallerType -eq 'portable')
if ($isPortable -and (Test-Property -Object $config -Name 'scope')) {
    throw 'Scope is not supported for portable installers. Remove scope from the configuration.'
}
if ($installerType -eq 'zip' -and [string]::IsNullOrWhiteSpace($nestedInstallerType)) {
    throw 'ZIP installers require nestedInstallerType.'
}

$computedInstallers = [System.Collections.Generic.List[object]]::new()
foreach ($installer in $installers) {
    $architecture = [string] (Get-RequiredValue -Object $installer -Name 'architecture')
    $installerUrl = [string] (Get-RequiredValue -Object $installer -Name 'installerUrl')
    $uri = $null
    if (-not [System.Uri]::TryCreate($installerUrl, [System.UriKind]::Absolute, [ref] $uri) -or $uri.Scheme -ne 'https') {
        throw "installerUrl must be an absolute HTTPS URL: $installerUrl"
    }
    if ($isPortable -and (Test-Property -Object $installer -Name 'scope')) {
        throw 'Scope is not supported for portable installers. Remove installer-level scope from the configuration.'
    }
    $hash = Get-InstallerSha256 -Installer $installer -IsOffline ([bool] $Offline)
    $computedInstallers.Add([pscustomobject]@{
        Source = $installer
        Architecture = $architecture
        InstallerUrl = $installerUrl
        InstallerSha256 = $hash
    })
}

$schemaBase = 'https://aka.ms'
$files = [ordered]@{}

$versionLines = [System.Collections.Generic.List[string]]::new()
$versionLines.Add("# yaml-language-server: `$schema=$schemaBase/winget-manifest.version.$ManifestVersion.schema.json")
$versionLines.Add('')
$versionLines.Add("PackageIdentifier: $(ConvertTo-YamlScalar $packageIdentifier)")
$versionLines.Add("PackageVersion: $(ConvertTo-YamlScalar $packageVersion)")
$versionLines.Add("DefaultLocale: $(ConvertTo-YamlScalar $defaultLocale)")
$versionLines.Add('ManifestType: version')
$versionLines.Add("ManifestVersion: $(ConvertTo-YamlScalar $ManifestVersion)")
$files["$packageIdentifier.yaml"] = $versionLines.ToArray()

$installerLines = [System.Collections.Generic.List[string]]::new()
$installerLines.Add("# yaml-language-server: `$schema=$schemaBase/winget-manifest.installer.$ManifestVersion.schema.json")
$installerLines.Add('')
$installerLines.Add("PackageIdentifier: $(ConvertTo-YamlScalar $packageIdentifier)")
$installerLines.Add("PackageVersion: $(ConvertTo-YamlScalar $packageVersion)")
$installerLines.Add("InstallerType: $(ConvertTo-YamlScalar $installerType)")
if (-not [string]::IsNullOrWhiteSpace($nestedInstallerType)) {
    $installerLines.Add("NestedInstallerType: $(ConvertTo-YamlScalar $nestedInstallerType)")
}
if (Test-Property -Object $config -Name 'archiveBinariesDependOnPath') {
    $installerLines.Add("ArchiveBinariesDependOnPath: $(ConvertTo-YamlScalar ([bool] $config.archiveBinariesDependOnPath))")
}
if (Test-Property -Object $config -Name 'scope') {
    $installerLines.Add("Scope: $(ConvertTo-YamlScalar $config.scope)")
}
foreach ($entry in @(
    @{ Property = 'minimumOSVersion'; Yaml = 'MinimumOSVersion' },
    @{ Property = 'upgradeBehavior'; Yaml = 'UpgradeBehavior' }
)) {
    Add-OptionalScalar -Lines $installerLines -Object $config -PropertyName $entry.Property -YamlName $entry.Yaml
}
if (Test-Property -Object $config -Name 'installModes') {
    Add-StringList -Lines $installerLines -YamlName 'InstallModes' -Values $config.installModes
}
if (Test-Property -Object $config -Name 'installerSwitches') {
    Add-InstallerSwitches -Lines $installerLines -Switches $config.installerSwitches
}
if (Test-Property -Object $config -Name 'commands') {
    Add-StringList -Lines $installerLines -YamlName 'Commands' -Values $config.commands
}
Add-OptionalScalar -Lines $installerLines -Object $config -PropertyName 'releaseDate' -YamlName 'ReleaseDate'
$installerLines.Add('Installers:')
foreach ($computed in $computedInstallers) {
    $installer = $computed.Source
    $installerLines.Add("- Architecture: $(ConvertTo-YamlScalar $computed.Architecture)")
    foreach ($entry in @(
        @{ Property = 'installerLocale'; Yaml = 'InstallerLocale' },
        @{ Property = 'scope'; Yaml = 'Scope' },
        @{ Property = 'productCode'; Yaml = 'ProductCode' },
        @{ Property = 'packageFamilyName'; Yaml = 'PackageFamilyName' }
    )) {
        if (Test-Property -Object $installer -Name $entry.Property) {
            $value = $installer.$($entry.Property)
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string] $value)) {
                $installerLines.Add("  $($entry.Yaml): $(ConvertTo-YamlScalar $value)")
            }
        }
    }
    if (Test-Property -Object $installer -Name 'installerSwitches') {
        Add-InstallerSwitches -Lines $installerLines -Switches $installer.installerSwitches -Indent '  '
    }
    if (Test-Property -Object $installer -Name 'nestedInstallerFiles') {
        $nestedFiles = @($installer.nestedInstallerFiles)
        if ($nestedFiles.Count -gt 0) {
            $installerLines.Add('  NestedInstallerFiles:')
            foreach ($nestedFile in $nestedFiles) {
                $relativePath = Get-RequiredValue -Object $nestedFile -Name 'relativeFilePath'
                $installerLines.Add("  - RelativeFilePath: $(ConvertTo-YamlScalar $relativePath)")
                if (Test-Property -Object $nestedFile -Name 'portableCommandAlias') {
                    $installerLines.Add("    PortableCommandAlias: $(ConvertTo-YamlScalar $nestedFile.portableCommandAlias)")
                }
            }
        }
    }
    $installerLines.Add("  InstallerUrl: $(ConvertTo-YamlScalar $computed.InstallerUrl)")
    $installerLines.Add("  InstallerSha256: $($computed.InstallerSha256)")
}
$installerLines.Add('ManifestType: installer')
$installerLines.Add("ManifestVersion: $(ConvertTo-YamlScalar $ManifestVersion)")
$files["$packageIdentifier.installer.yaml"] = $installerLines.ToArray()

$defaultLocaleLines = [System.Collections.Generic.List[string]]::new()
$defaultLocaleLines.Add("# yaml-language-server: `$schema=$schemaBase/winget-manifest.defaultLocale.$ManifestVersion.schema.json")
$defaultLocaleLines.Add('')
$defaultLocaleLines.Add("PackageIdentifier: $(ConvertTo-YamlScalar $packageIdentifier)")
$defaultLocaleLines.Add("PackageVersion: $(ConvertTo-YamlScalar $packageVersion)")
$defaultLocaleLines.Add("PackageLocale: $(ConvertTo-YamlScalar $defaultLocale)")
$defaultLocaleLines.Add("Publisher: $(ConvertTo-YamlScalar $publisher)")
foreach ($entry in @(
    @{ Property = 'publisherUrl'; Yaml = 'PublisherUrl' },
    @{ Property = 'publisherSupportUrl'; Yaml = 'PublisherSupportUrl' }
)) {
    Add-OptionalScalar -Lines $defaultLocaleLines -Object $config -PropertyName $entry.Property -YamlName $entry.Yaml
}
$defaultLocaleLines.Add("PackageName: $(ConvertTo-YamlScalar $packageName)")
Add-OptionalScalar -Lines $defaultLocaleLines -Object $config -PropertyName 'packageUrl' -YamlName 'PackageUrl'
$defaultLocaleLines.Add("License: $(ConvertTo-YamlScalar $license)")
Add-OptionalScalar -Lines $defaultLocaleLines -Object $config -PropertyName 'licenseUrl' -YamlName 'LicenseUrl'
$defaultLocaleLines.Add("ShortDescription: $(ConvertTo-YamlScalar $shortDescription)")
foreach ($entry in @(
    @{ Property = 'description'; Yaml = 'Description' },
    @{ Property = 'moniker'; Yaml = 'Moniker' }
)) {
    Add-OptionalScalar -Lines $defaultLocaleLines -Object $config -PropertyName $entry.Property -YamlName $entry.Yaml
}
if (Test-Property -Object $config -Name 'tags') {
    Add-StringList -Lines $defaultLocaleLines -YamlName 'Tags' -Values $config.tags
}
Add-OptionalScalar -Lines $defaultLocaleLines -Object $config -PropertyName 'releaseNotesUrl' -YamlName 'ReleaseNotesUrl'
$defaultLocaleLines.Add('ManifestType: defaultLocale')
$defaultLocaleLines.Add("ManifestVersion: $(ConvertTo-YamlScalar $ManifestVersion)")
$files["$packageIdentifier.locale.$defaultLocale.yaml"] = $defaultLocaleLines.ToArray()

if (Test-Property -Object $config -Name 'locales') {
    foreach ($locale in @($config.locales)) {
        $localeName = [string] (Get-RequiredValue -Object $locale -Name 'packageLocale')
        if ($localeName -eq $defaultLocale) {
            throw "Locale '$localeName' duplicates defaultLocale."
        }

        $localeLines = [System.Collections.Generic.List[string]]::new()
        $localeLines.Add("# yaml-language-server: `$schema=$schemaBase/winget-manifest.locale.$ManifestVersion.schema.json")
        $localeLines.Add('')
        $localeLines.Add("PackageIdentifier: $(ConvertTo-YamlScalar $packageIdentifier)")
        $localeLines.Add("PackageVersion: $(ConvertTo-YamlScalar $packageVersion)")
        $localeLines.Add("PackageLocale: $(ConvertTo-YamlScalar $localeName)")
        foreach ($entry in @(
            @{ Property = 'publisher'; Yaml = 'Publisher' },
            @{ Property = 'publisherUrl'; Yaml = 'PublisherUrl' },
            @{ Property = 'publisherSupportUrl'; Yaml = 'PublisherSupportUrl' },
            @{ Property = 'packageName'; Yaml = 'PackageName' },
            @{ Property = 'packageUrl'; Yaml = 'PackageUrl' },
            @{ Property = 'license'; Yaml = 'License' },
            @{ Property = 'licenseUrl'; Yaml = 'LicenseUrl' },
            @{ Property = 'shortDescription'; Yaml = 'ShortDescription' },
            @{ Property = 'description'; Yaml = 'Description' }
        )) {
            $value = Get-LocaleValue -Locale $locale -Defaults $config -Name $entry.Property
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string] $value)) {
                $localeLines.Add("$($entry.Yaml): $(ConvertTo-YamlScalar $value)")
            }
        }
        $localeTags = Get-LocaleValue -Locale $locale -Defaults $config -Name 'tags'
        Add-StringList -Lines $localeLines -YamlName 'Tags' -Values $localeTags
        $localeReleaseNotesUrl = Get-LocaleValue -Locale $locale -Defaults $config -Name 'releaseNotesUrl'
        if ($null -ne $localeReleaseNotesUrl -and -not [string]::IsNullOrWhiteSpace([string] $localeReleaseNotesUrl)) {
            $localeLines.Add("ReleaseNotesUrl: $(ConvertTo-YamlScalar $localeReleaseNotesUrl)")
        }
        $localeLines.Add('ManifestType: locale')
        $localeLines.Add("ManifestVersion: $(ConvertTo-YamlScalar $ManifestVersion)")
        $files["$packageIdentifier.locale.$localeName.yaml"] = $localeLines.ToArray()
    }
}

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory)) {
    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
}

foreach ($fileName in $files.Keys) {
    $targetPath = Join-Path $resolvedOutputDirectory $fileName
    if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
        throw "Refusing to overwrite '$targetPath'. Use -Force after verifying the target directory."
    }
}

$writtenFiles = [System.Collections.Generic.List[string]]::new()
foreach ($fileName in $files.Keys) {
    $targetPath = Join-Path $resolvedOutputDirectory $fileName
    Write-Utf8File -Path $targetPath -Lines $files[$fileName]
    $writtenFiles.Add($targetPath)
}

$validated = $false
if ($Validate) {
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $wingetCommand) {
        throw 'winget was not found. Install or repair Windows App Installer before validation.'
    }
    & $wingetCommand.Source validate --manifest $resolvedOutputDirectory --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget validate failed with exit code $LASTEXITCODE."
    }
    $validated = $true
}

[pscustomobject]@{
    PackageIdentifier = $packageIdentifier
    PackageVersion = $packageVersion
    OutputDirectory = $resolvedOutputDirectory
    Files = $writtenFiles.ToArray()
    InstallerHashes = @($computedInstallers | ForEach-Object {
        [pscustomobject]@{
            Architecture = $_.Architecture
            InstallerUrl = $_.InstallerUrl
            InstallerSha256 = $_.InstallerSha256
        }
    })
    Validated = $validated
} | ConvertTo-Json -Depth 5

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$RootPath = 'D:\',

    [ValidateSet('Basic', 'Developer', 'Designer', 'Photographer', 'Office', 'Learning', 'PhotographyLearning', 'Private', 'MultiPc', 'Full')]
    [string]$Profile = 'Basic',

    [switch]$IncludeDeveloper,
    [switch]$IncludeDesigner,
    [switch]$IncludePhotographer,
    [switch]$IncludeOffice,
    [switch]$IncludeLearning,
    [switch]$IncludePhotographyLearning,
    [switch]$IncludePrivate,
    [switch]$IncludeMultiPc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'RootPath cannot be empty.'
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-SafeRoot {
    param([string]$Path)

    $normalized = Get-NormalizedRoot -Path $Path
    $blockedRoots = @(
        $env:WINDIR,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:ProgramData
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        [System.IO.Path]::GetFullPath($_)
    }

    foreach ($blocked in $blockedRoots) {
        if ($normalized.StartsWith($blocked, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to create workstation folders inside system location: $blocked"
        }
    }

    return $normalized
}

function Join-RootPath {
    param(
        [string]$Root,
        [string]$Child
    )

    return [System.IO.Path]::Combine($Root, $Child)
}

function Add-Paths {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Root,
        [string[]]$RelativePaths
    )

    foreach ($relativePath in $RelativePaths) {
        $List.Add((Join-RootPath -Root $Root -Child $relativePath))
    }
}

function Get-RequestedModules {
    $modules = [ordered]@{
        Developer = [bool]$IncludeDeveloper
        Designer = [bool]$IncludeDesigner
        Photographer = [bool]$IncludePhotographer
        Office = [bool]$IncludeOffice
        Learning = [bool]$IncludeLearning
        PhotographyLearning = [bool]$IncludePhotographyLearning
        Private = [bool]$IncludePrivate
        MultiPc = [bool]$IncludeMultiPc
    }

    switch ($Profile) {
        'Developer' { $modules.Developer = $true }
        'Designer' { $modules.Designer = $true }
        'Photographer' { $modules.Photographer = $true }
        'Office' { $modules.Office = $true }
        'Learning' { $modules.Learning = $true }
        'PhotographyLearning' {
            $modules.Learning = $true
            $modules.PhotographyLearning = $true
        }
        'Private' { $modules.Private = $true }
        'MultiPc' { $modules.MultiPc = $true }
        'Full' {
            foreach ($key in @($modules.Keys)) {
                $modules[$key] = $true
            }
        }
    }

    return $modules
}

function Get-WorkstationFolderPaths {
    param([string]$Root)

    $year = (Get-Date).Year.ToString()
    $modules = Get-RequestedModules
    $paths = [System.Collections.Generic.List[string]]::new()

    Add-Paths -List $paths -Root $Root -RelativePaths @(
        '00_Inbox',
        '10_Work',
        '20_Personal',
        '30_Code',
        '40_Media',
        '50_Archive',
        '90_Temp'
    )

    if ($modules.Developer) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '30_Code\Work',
            '30_Code\Work\CompanyName',
            '30_Code\Personal',
            '30_Code\Personal\Products',
            '30_Code\Personal\OpenSource',
            '30_Code\Personal\Labs',
            '30_Code\Forks',
            '30_Code\Tools',
            '30_Code\Sandbox'
        )
    }

    if ($modules.Designer) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '40_Media\Design',
            '40_Media\Design\Projects',
            '40_Media\Design\Assets',
            '40_Media\Design\Fonts',
            '40_Media\Design\Icons',
            '40_Media\Design\Screenshots',
            '40_Media\Design\References',
            '40_Media\Design\Exports',
            '40_Media\Design\Archive'
        )
    }

    if ($modules.Photographer) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            "40_Media\Photos\$year",
            '40_Media\Photos\Lightroom',
            "40_Media\Videos\$year",
            '40_Media\Videos\Projects',
            '40_Media\Exports',
            '40_Media\Assets'
        )
    }

    if ($modules.Office) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '10_Work\Documents',
            '10_Work\Meetings',
            '10_Work\Reports',
            '10_Work\References',
            '10_Work\Projects',
            '10_Work\Archive'
        )
    }

    if ($modules.Learning) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '20_Personal\Learning',
            '20_Personal\Learning\Courses',
            '20_Personal\Learning\Notes',
            '20_Personal\Learning\Books',
            '20_Personal\Learning\Papers',
            '20_Personal\Learning\Assignments',
            '20_Personal\Learning\Exams'
        )
    }

    if ($modules.PhotographyLearning) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '20_Personal\Learning',
            '20_Personal\Learning\Photography',
            '20_Personal\Learning\Photography\Courses',
            '20_Personal\Learning\Photography\Notes',
            '20_Personal\Learning\Photography\Books',
            '20_Personal\Learning\Photography\References',
            '20_Personal\Learning\Photography\Practice',
            '20_Personal\Learning\Photography\Attachments'
        )
    }

    if ($modules.Private) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '20_Personal\_Private',
            '20_Personal\_Private\Identity',
            '20_Personal\_Private\Contracts',
            '20_Personal\_Private\Tax',
            '20_Personal\_Private\Bank',
            '20_Personal\_Private\Insurance',
            '20_Personal\_Private\Legal'
        )
    }

    if ($modules.MultiPc) {
        Add-Paths -List $paths -Root $Root -RelativePaths @(
            '60_Devices',
            '60_Devices\PrimaryWorkstation',
            '60_Devices\PersonalMain',
            '60_Devices\TestMachine',
            '60_Devices\MobileDevices',
            '60_Devices\NAS_ExternalStorage'
        )
    }

    return $paths | Select-Object -Unique
}

$safeRoot = Assert-SafeRoot -Path $RootPath
$pathsToCreate = Get-WorkstationFolderPaths -Root $safeRoot

Write-Host "Target root: $safeRoot"
Write-Host "Planned folders: $($pathsToCreate.Count)"

foreach ($path in $pathsToCreate) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        Write-Host "Exists:  $path"
        continue
    }

    if ($PSCmdlet.ShouldProcess($path, 'Create directory')) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Created: $path"
    }
}

[CmdletBinding()]
param(
  [string]$HomeDirectory = $HOME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DotfilesDir = $PSScriptRoot
$BackupRoot = Join-Path $DotfilesDir 'backup'
$script:BackupDir = $null
$Platform = 'windows'

$ManagedFiles = @(
  [pscustomobject]@{
    Source = '.tmux.conf'
    Target = '.tmux.conf'
    Platforms = @('linux')
  },
  [pscustomobject]@{
    Source = '.config/wezterm/wezterm.lua'
    Target = '.config/wezterm/wezterm.lua'
    Platforms = @('linux', 'windows')
  },
  [pscustomobject]@{
    Source = '.config/herdr/config.toml'
    Target = '.config/herdr/config.toml'
    Platforms = @('linux', 'windows')
  },
  [pscustomobject]@{
    Source = 'assets/images/seed-gundam.jpg'
    Target = '.config/wezterm/images/seed-gundam.jpg'
    Platforms = @('linux', 'windows')
  }
)

function Require-Windows {
  if ($env:OS -ne 'Windows_NT') {
    throw 'Unsupported system: this installer is intended for Windows hosts.'
  }
}

function Resolve-FullPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return [System.IO.Path]::GetFullPath($Path)
}

function Join-HomePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  return Join-Path $HomeDirectory ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
}

function Test-ManagedOnPlatform {
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Platforms,
    [Parameter(Mandatory = $true)]
    [string]$CurrentPlatform
  )

  return $Platforms -contains $CurrentPlatform
}

function Ensure-BackupDir {
  if ($script:BackupDir) {
    return
  }

  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $candidate = Join-Path $BackupRoot $timestamp
  $counter = 1

  while (Test-Path -LiteralPath $candidate) {
    $counter += 1
    $candidate = Join-Path $BackupRoot "$timestamp-$counter"
  }

  $script:BackupDir = $candidate
  New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
}

function Get-BackupRelativePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  $fullTarget = Resolve-FullPath $Target
  $fullHome = (Resolve-FullPath $HomeDirectory).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

  if ($fullTarget.StartsWith($fullHome, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullTarget.Substring($fullHome.Length)
  }

  return Split-Path -Leaf $Target
}

function Backup-ExistingFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  Ensure-BackupDir

  $relativePath = Get-BackupRelativePath $Target
  $backupPath = Join-Path $script:BackupDir $relativePath
  $backupParent = Split-Path -Parent $backupPath

  if ($backupParent) {
    New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
  }

  Write-Host "Backing up existing file: $Target -> $backupPath"
  Move-Item -LiteralPath $Target -Destination $backupPath
}

function Get-SymlinkTarget {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $item = Get-Item -LiteralPath $Path -Force

  if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
    return $null
  }

  $targetProperty = $item.PSObject.Properties['Target']
  if ($null -eq $targetProperty -or $null -eq $targetProperty.Value) {
    return $null
  }

  if ($targetProperty.Value -is [array]) {
    return $targetProperty.Value[0]
  }

  return $targetProperty.Value
}

function Test-ExistingLinkToSource {
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileSystemInfo]$Item,
    [Parameter(Mandatory = $true)]
    [string]$Source
  )

  $sourceFullPath = Resolve-FullPath $Source

  if (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    $currentTarget = Get-SymlinkTarget $Item.FullName

    if ($currentTarget) {
      $currentFullTarget = Resolve-FullPath $currentTarget
      return $currentFullTarget.Equals($sourceFullPath, [System.StringComparison]::OrdinalIgnoreCase)
    }
  }

  if ($Item.PSObject.Properties['LinkType'] -and $Item.LinkType -eq 'HardLink' -and $Item.PSObject.Properties['Target']) {
    foreach ($target in $Item.Target) {
      $currentFullTarget = Resolve-FullPath $target

      if ($currentFullTarget.Equals($sourceFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
      }
    }
  }

  return $false
}

function New-ManagedLink {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  try {
    New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
    Write-Host "Linked: $Target -> $Source"
    return
  } catch {
    $symlinkError = $_.Exception.Message
  }

  try {
    New-Item -ItemType HardLink -Path $Target -Target $Source | Out-Null
    Write-Host "Hard linked: $Target -> $Source"
  } catch {
    throw "Failed to create link: $Target -> $Source. Enable Windows Developer Mode or run PowerShell as Administrator for symlinks. Symlink error: $symlinkError Hard link error: $($_.Exception.Message)"
  }
}

function Link-File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  if (!(Test-Path -LiteralPath $Source -PathType Leaf)) {
    throw "Missing source: $Source"
  }

  $existingItem = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue

  if ($existingItem) {
    if (Test-ExistingLinkToSource $existingItem $Source) {
      Write-Host "Already linked: $Target -> $Source"
      return
    }

    $currentTarget = Get-SymlinkTarget $Target
    if ($currentTarget) {
      Write-Host "Replacing symlink: $Target -> $currentTarget"
      Remove-Item -LiteralPath $Target -Force
    } else {
      Backup-ExistingFile $Target
    }
  }

  $targetParent = Split-Path -Parent $Target
  if ($targetParent) {
    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
  }

  New-ManagedLink $Source $Target
}

function Install-Dotfiles {
  foreach ($file in $ManagedFiles) {
    if (!(Test-ManagedOnPlatform $file.Platforms $Platform)) {
      Write-Host "Skipping $($file.Target) for $Platform."
      continue
    }

    $source = Join-Path $DotfilesDir ($file.Source -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $target = Join-HomePath $file.Target

    Link-File $source $target
  }
}

function Main {
  Require-Windows
  Install-Dotfiles

  Write-Host 'Done.'
}

Main

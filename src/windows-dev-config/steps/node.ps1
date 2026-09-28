<#
.SYNOPSIS
  Installs Node.js through nvm and the default global npm tools.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Edit these two to move to another Node major version or a different global tool set.
$Script:DevConfigNodeMajorVersion  = '24'
$Script:DevConfigNpmGlobalPackages = @('pnpm', 'yarn', 'rimraf')

function Get-DevConfigNvmCommand {
    if (Get-Command 'nvm' -ErrorAction SilentlyContinue) {
        return 'nvm'
    }
    # nvm-windows drops nvm.exe here; this process may not have seen the updated PATH yet.
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'nvm\nvm.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'nvm\nvm.exe')
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $null
}

# nvm needs NVM_HOME/NVM_SYMLINK from the machine environment, and npm lives under the symlink,
# so both the variables and the two directories are added to this session before the checks run.
function Initialize-DevConfigNvmSession {
    Update-DevConfigSessionPath

    $nvm = Get-DevConfigNvmCommand
    if (-not $nvm) {
        return
    }

    foreach ($name in @('NVM_HOME', 'NVM_SYMLINK')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if ($value) {
            Set-Item -Path "env:$name" -Value $value
        }
    }
    if (-not [Environment]::GetEnvironmentVariable('NVM_HOME')) {
        $nvmRoot = if ($nvm -like '*.exe') { Split-Path -Parent $nvm } else { Join-Path $env:ProgramFiles 'nvm' }
        Set-Item -Path 'env:NVM_HOME' -Value $nvmRoot
    }
    if (-not [Environment]::GetEnvironmentVariable('NVM_SYMLINK')) {
        Set-Item -Path 'env:NVM_SYMLINK' -Value (Join-Path $env:ProgramFiles 'nodejs')
    }

    foreach ($directory in @(
        [Environment]::GetEnvironmentVariable('NVM_HOME'),
        [Environment]::GetEnvironmentVariable('NVM_SYMLINK')
    )) {
        if ($directory -and (($env:Path -split ';') -notcontains $directory)) {
            $env:Path = "$directory;$env:Path"
        }
    }
}

# nvm list marks the active version with a leading *, so the check also confirms it is in use.
function Test-DevConfigNvmNodeMajorActive {
    $nvm = Get-DevConfigNvmCommand
    if (-not $nvm) {
        return $false
    }
    $r = Invoke-DevConfigNativeCommand -FilePath $nvm -Arguments @('list')
    if ($r.ExitCode -ne 0 -or -not $r.Output) {
        return $false
    }
    return ($r.Output -match "(?m)^\s*\*\s*$([regex]::Escape($Script:DevConfigNodeMajorVersion))\.\d+\.\d+")
}

function Install-DevConfigNvmNode {
    $nvm = Get-DevConfigNvmCommand
    if (-not $nvm) {
        throw 'nvm is not available yet; re-run this setup once the packages phase has installed nvm.'
    }

    # nvm install is a no-op for a version that is already installed, so re-runs are safe.
    $r = Invoke-DevConfigNativeCommand -FilePath $nvm -Arguments @('install', $Script:DevConfigNodeMajorVersion)
    if ($r.ExitCode -ne 0) {
        Write-Host $r.Output
        throw "nvm install $Script:DevConfigNodeMajorVersion failed with exit code $($r.ExitCode)."
    }

    # use points the nodejs symlink at this major version so npm and node resolve to it on PATH.
    $use = Invoke-DevConfigNativeCommand -FilePath $nvm -Arguments @('use', $Script:DevConfigNodeMajorVersion)
    if ($use.ExitCode -ne 0) {
        Write-Host $use.Output
        throw "nvm use $Script:DevConfigNodeMajorVersion failed with exit code $($use.ExitCode)."
    }
    Write-Host "  Node $Script:DevConfigNodeMajorVersion is installed and active through nvm."
}

function Test-DevConfigNpmGlobalsInstalled {
    if (-not (Get-Command 'npm' -ErrorAction SilentlyContinue)) {
        return $false
    }
    # npm ls --json keeps emitting a parseable tree even when it reports problems alongside it.
    $r = Invoke-DevConfigNativeCommand -FilePath 'npm' -Arguments @('ls', '-g', '--depth=0', '--json')
    if (-not $r.Output) {
        return $false
    }
    $dependencies = $null
    try {
        $dependencies = ($r.Output | ConvertFrom-Json).dependencies
    } catch {
        return $false
    }
    if (-not $dependencies) {
        return $false
    }
    $installed = @($dependencies.PSObject.Properties.Name)
    foreach ($package in $Script:DevConfigNpmGlobalPackages) {
        if ($installed -notcontains $package) {
            return $false
        }
    }
    return $true
}

function Install-DevConfigNpmGlobals {
    if (-not (Get-Command 'npm' -ErrorAction SilentlyContinue)) {
        throw 'npm is not on PATH yet; open a new terminal once nvm has installed Node, then re-run this setup.'
    }
    $r = Invoke-DevConfigNativeCommand -FilePath 'npm' -Arguments (@('install', '-g') + $Script:DevConfigNpmGlobalPackages)
    if ($r.ExitCode -ne 0) {
        Write-Host $r.Output
        throw "npm install -g failed with exit code $($r.ExitCode)."
    }
    Write-Host "  Global npm tools installed: $($Script:DevConfigNpmGlobalPackages -join ', ')."
}

function Invoke-NodePhase {
    # Show the header before nvm setup; skip it when a resumed run summarizes this phase.
    if (-not $Script:DevConfigResumed) {
        Show-DevConfigPhaseHeader
    }
    Initialize-DevConfigNvmSession

    # BestEffort keeps a flaky npm registry from blocking the phases that follow.
    $steps = @(
        New-DevConfigStep -Name "Node$($Script:DevConfigNodeMajorVersion)ViaNvm" `
            -Description "nvm install and use Node $Script:DevConfigNodeMajorVersion" -BestEffort `
            -Check { Test-DevConfigNvmNodeMajorActive } `
            -Apply { Install-DevConfigNvmNode }
        New-DevConfigStep -Name 'NpmGlobals' `
            -Description "npm install -g $($Script:DevConfigNpmGlobalPackages -join ' ')" -BestEffort `
            -Check { Test-DevConfigNpmGlobalsInstalled } `
            -Apply { Install-DevConfigNpmGlobals }
    )

    Invoke-DevConfigSteps -Steps $steps
}

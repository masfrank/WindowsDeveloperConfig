<#
.SYNOPSIS
  End-of-run picker that installs optional vibe coding CLI tools.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Idle timeout for the picker so an unattended run does not hold the window open forever.
$Script:DevConfigVibeIdleSeconds = 600

# All rows start unchecked; a row installs only after Space toggles it on.
function Get-DevConfigVibeCodingTools {
    return @(
        [pscustomobject]@{
            Label   = 'npm global CLIs: codex, claude-code, qwen-code, dsh, opencode, pi-coding-agent'
            Command = 'npm install -g @openai/codex @cometix/claude-code @qwen-code/qwen-code @deepseek-ai/dsh @opencode/cli @earendil-works/pi-coding-agent'
            Install = {
                if (-not (Get-Command 'npm' -ErrorAction SilentlyContinue)) {
                    throw 'npm is not on PATH yet; Node has to be installed through nvm first.'
                }
                $r = Invoke-DevConfigNativeCommand -FilePath 'npm' -Arguments @(
                    'install', '-g',
                    '@openai/codex',
                    '@cometix/claude-code',
                    '@qwen-code/qwen-code',
                    '@deepseek-ai/dsh',
                    '@opencode/cli',
                    '@earendil-works/pi-coding-agent'
                )
                if ($r.ExitCode -ne 0) {
                    Write-Host $r.Output
                    throw "npm install -g failed with exit code $($r.ExitCode)."
                }
            }
        }
        [pscustomobject]@{
            Label   = 'Grok CLI (x.ai)'
            Command = 'irm https://x.ai/cli/install.ps1 | iex'
            Install = { Invoke-DevConfigRemoteInstallScript -Uri 'https://x.ai/cli/install.ps1' }
        }
        [pscustomobject]@{
            Label   = 'Antigravity CLI (Google)'
            Command = 'irm https://antigravity.google/cli/install.ps1 | iex'
            Install = { Invoke-DevConfigRemoteInstallScript -Uri 'https://antigravity.google/cli/install.ps1' }
        }
        [pscustomobject]@{
            Label   = 'Oh My Posh via omp.sh (a second copy next to the winget one)'
            Command = 'irm https://omp.sh/install.ps1 | iex'
            Install = { Invoke-DevConfigRemoteInstallScript -Uri 'https://omp.sh/install.ps1' }
        }
    )
}

# Downloads and runs the same install script the picker prints, exactly as the irm ... | iex one-liners do.
function Invoke-DevConfigRemoteInstallScript {
    param(
        [Parameter(Mandatory)] [string] $Uri
    )
    Write-Host "  Downloading and running $Uri ..." -ForegroundColor DarkGray
    Invoke-Expression (Invoke-RestMethod -Uri $Uri -UseBasicParsing)
}

# Box characters are built with [char] so the file stays plain ASCII for any console host.
function Write-DevConfigVibeBoxEdge {
    param(
        [Parameter(Mandatory)] [char] $Left,
        [Parameter(Mandatory)] [char] $Fill,
        [Parameter(Mandatory)] [char] $Right,
        [int] $Width = 64
    )
    # A string repeat, not a char repeat: PowerShell has no [char] * [int] operator.
    Write-Host ($Left + ([string]$Fill * $Width) + $Right) -ForegroundColor Cyan
}

function Write-DevConfigVibeBoxText {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [int] $Width = 64
    )
    Write-Host ("$([char]0x2502)" + $Text.PadRight($Width) + "$([char]0x2502)") -ForegroundColor Cyan
}

function Write-DevConfigVibeHeader {
    Write-Host ''
    Write-DevConfigVibeBoxEdge -Left ([char]0x256D) -Fill ([char]0x2500) -Right ([char]0x256E)
    Write-DevConfigVibeBoxText -Text 'Vibe coding tools -- optional, pick any or none'
    Write-DevConfigVibeBoxText -Text 'Up/Down: move    Space: toggle    Enter: run checked    Esc: skip'
    Write-DevConfigVibeBoxEdge -Left ([char]0x2570) -Fill ([char]0x2500) -Right ([char]0x256F)
}

function Write-DevConfigVibeList {
    param(
        [Parameter(Mandatory)] [object[]] $Tools,
        [Parameter(Mandatory)] [bool[]] $Checked,
        [Parameter(Mandatory)] [int] $Current
    )
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        $mark    = if ($Checked[$i]) { 'x' } else { ' ' }
        $pointer = if ($i -eq $Current) { '>' } else { ' ' }
        Write-Host "  $pointer [$mark] $($Tools[$i].Label)"
    }
    Write-Host '  Up/Down: move    Space: toggle    Enter: run checked    Esc: skip' -ForegroundColor DarkGray
}

# Blanking the drawn lines in place keeps the picker still instead of scrolling the window.
function Clear-DevConfigVibeListLines {
    param(
        [Parameter(Mandatory)] [int] $Count
    )
    try {
        for ($i = 0; $i -lt $Count; $i++) {
            $line = [Math]::Max(0, [Console]::CursorTop - 1)
            [Console]::SetCursorPosition(0, $line)
            [Console]::Write(' ' * [Console]::WindowWidth)
            [Console]::SetCursorPosition(0, $line)
        }
    } catch {
        # A console without cursor control just prints a fresh list on each keypress.
    }
}

# Returns the key pressed, or $null after the idle timeout so unattended runs continue.
function Read-DevConfigVibeKey {
    $deadline = (Get-Date).AddSeconds($Script:DevConfigVibeIdleSeconds)
    while ($true) {
        if ([Console]::KeyAvailable) {
            return [Console]::ReadKey($true).Key
        }
        if ((Get-Date) -ge $deadline) {
            return $null
        }
        Start-Sleep -Milliseconds 200
    }
}

function Write-DevConfigVibeManualCommands {
    param(
        [Parameter(Mandatory)] [object[]] $Tools
    )
    Write-Host '  Nothing was installed. To run any of these by hand later:' -ForegroundColor DarkGray
    foreach ($tool in $Tools) {
        Write-Host "    $($tool.Command)" -ForegroundColor DarkGray
    }
}

function Install-DevConfigVibeTools {
    param(
        [Parameter(Mandatory)] [object[]] $Tools,
        [Parameter(Mandatory)] [bool[]] $Checked
    )
    $picked = @()
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        if ($Checked[$i]) {
            $picked += $Tools[$i]
        }
    }
    if ($picked.Count -eq 0) {
        Write-DevConfigVibeManualCommands -Tools $Tools
        return
    }

    foreach ($tool in $picked) {
        Write-Host "  -> $($tool.Label)..." -ForegroundColor DarkCyan
        try {
            & $tool.Install
            Write-Host "  $Script:DevConfigCheckMark $($tool.Label) done" -ForegroundColor Green
        } catch {
            # One failing tool must not stop the ones after it or lose the end-of-run summary.
            Write-Host "  ! $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Show-DevConfigVibeCodingPicker {
    param(
        [Parameter(Mandatory)] [object[]] $Tools
    )

    Write-DevConfigVibeHeader

    # Redirected input (or no console at all) cannot answer the prompt; list the commands instead.
    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }
    if (-not $interactive) {
        Write-Host '  Console input is redirected, so the optional tools were skipped.' -ForegroundColor DarkGray
        Write-DevConfigVibeManualCommands -Tools $Tools
        return
    }

    $checked = @($false) * $Tools.Count
    $current = 0
    while ($true) {
        Write-DevConfigVibeList -Tools $Tools -Checked $checked -Current $current

        $key = Read-DevConfigVibeKey
        if ($null -eq $key) {
            Clear-DevConfigVibeListLines -Count ($Tools.Count + 1)
            Write-DevConfigVibeHeader
            Write-Host '  No selection was made in time, so the optional tools were skipped.' -ForegroundColor DarkGray
            Write-DevConfigVibeManualCommands -Tools $Tools
            return
        }

        if ($key -eq 'Escape') {
            Write-DevConfigVibeManualCommands -Tools $Tools
            return
        }
        switch ($key) {
            'UpArrow'   { if ($current -gt 0) { $current-- } }
            'DownArrow' { if ($current -lt $Tools.Count - 1) { $current++ } }
            'Spacebar'  { $checked[$current] = -not $checked[$current] }
            'Enter'     {
                Clear-DevConfigVibeListLines -Count ($Tools.Count + 1)
                Install-DevConfigVibeTools -Tools $Tools -Checked $checked
                return
            }
        }

        Clear-DevConfigVibeListLines -Count ($Tools.Count + 1)
    }
}

function Invoke-VibeCodingPhase {
    Show-DevConfigPhaseHeader
    Show-DevConfigVibeCodingPicker -Tools (Get-DevConfigVibeCodingTools)
}

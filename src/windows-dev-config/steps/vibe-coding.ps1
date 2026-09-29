<#
.SYNOPSIS
  End-of-run picker that records the optional WSL2 tool picks and prints the one-line command that installs them.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Idle timeout for the picker so an unattended run does not hold the window open forever.
$Script:DevConfigVibeIdleSeconds = 600

# The companion script that runs inside the WSL2 distro; the calm-os Windows side installs none of these.
$Script:DevConfigVibeScriptUrl = 'https://raw.githubusercontent.com/masfrank/WindowsDeveloperConfig/main/src/wsl-vibe/install-vibe.sh'

# The distro the WSL side was set up with; falls back to the flow's default when run standalone.
function Get-DevConfigVibeDistroName {
    $known = Get-Variable -Name 'DevConfigWslDistroName' -Scope Script -ErrorAction SilentlyContinue
    if ($known -and $known.Value) {
        return $known.Value
    }
    return 'Ubuntu-24.04'
}

# Each pick maps to an --tools group understood by the WSL script. The WSL base install
# (zsh, zsh plugins, nvm, Node 24, pnpm/yarn/rimraf) is always part of the script.
function Get-DevConfigVibeCodingTools {
    return @(
        [pscustomobject]@{
            Label = 'npm agent CLIs: codex, claude-code, dsh, opencode, pi-coding-agent'
            Id    = 'codex'
        }
        [pscustomobject]@{
            Label = 'Grok CLI (x.ai)'
            Id    = 'grok'
        }
        [pscustomobject]@{
            Label = 'bun + oh-my-pi coding agent'
            Id    = 'bun'
        }
    )
}

function Get-DevConfigVibeScriptArgs {
    param(
        [Parameter(Mandatory)] [object[]] $Tools,
        [Parameter(Mandatory)] [bool[]] $Checked
    )
    $picked = @()
    for ($i = 0; $i -lt $Tools.Count; $i++) {
        if ($Checked[$i]) {
            $picked += $Tools[$i].Id
        }
    }
    if ($picked.Count -eq 0) {
        return '--base-only'
    }
    return "--tools $($picked -join ',')"
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
    Write-DevConfigVibeBoxText -Text 'Vibe coding tools -- optional, picked for install inside WSL2'
    Write-DevConfigVibeBoxText -Text 'Up/Down: move    Space: toggle    Enter: show command    Esc: skip'
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
    Write-Host '  Up/Down: move    Space: toggle    Enter: show command    Esc: skip' -ForegroundColor DarkGray
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

function Write-DevConfigVibeInstructions {
    param(
        [Parameter(Mandatory)] [string] $ScriptArgs
    )

    $url     = $Script:DevConfigVibeScriptUrl
    $distro  = Get-DevConfigVibeDistroName
    $install = "curl -fsSL $url | bash -s -- $ScriptArgs"
    Write-Host ''
    Write-Host 'Everything above is set. For the vibe coding tools, run this once INSIDE your' -ForegroundColor Green
    Write-Host 'WSL2 distro -- open it from the Start menu, then paste:' -ForegroundColor Green
    Write-Host "  $install" -ForegroundColor White
    Write-Host ''
    Write-Host 'You can also launch it from Windows without opening a terminal first:' -ForegroundColor DarkGray
    Write-Host "  wsl -d $distro -- bash -ic `"$install`"" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'The script installs zsh, the zsh plugins, nvm, Node 24, and pnpm/yarn/rimraf,' -ForegroundColor DarkGray
    Write-Host 'then whatever the picks above select. Nothing on the Windows side is touched.' -ForegroundColor DarkGray
    Write-Host "(Add --help to that script to see every option.)" -ForegroundColor DarkGray
}

function Show-DevConfigVibeCodingPicker {
    param(
        [Parameter(Mandatory)] [object[]] $Tools
    )

    Write-DevConfigVibeHeader

    # Redirected input (or no console at all) cannot answer the prompt; show the base command instead.
    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }
    if (-not $interactive) {
        Write-Host '  Console input is redirected, so nothing was picked.' -ForegroundColor DarkGray
        Write-DevConfigVibeInstructions -ScriptArgs '--base-only'
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
            Write-Host '  No selection was made in time.' -ForegroundColor DarkGray
            Write-DevConfigVibeInstructions -ScriptArgs '--base-only'
            return
        }

        if ($key -eq 'Escape') {
            Write-DevConfigVibeInstructions -ScriptArgs '--base-only'
            return
        }
        switch ($key) {
            'UpArrow'   { if ($current -gt 0) { $current-- } }
            'DownArrow' { if ($current -lt $Tools.Count - 1) { $current++ } }
            'Spacebar'  { $checked[$current] = -not $checked[$current] }
            'Enter'     {
                $scriptArgs = Get-DevConfigVibeScriptArgs -Tools $Tools -Checked $checked
                Clear-DevConfigVibeListLines -Count ($Tools.Count + 1)
                Write-DevConfigVibeInstructions -ScriptArgs $scriptArgs
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

$pass = 0; $fail = 0
function Check($label, [scriptblock]$test) {
    try {
        $ok = & $test
    } catch {
        $ok = $false
    }
    if ($ok) { Write-Host "PASS  $label" -ForegroundColor Green; $script:pass++ }
    else      { Write-Host "FAIL  $label" -ForegroundColor Red;   $script:fail++ }
}

# PowerShell 7
Check "pwsh --version starts with 7."             { (pwsh --version 2>$null) -match '^PowerShell 7\.' }

# File Explorer & taskbar
$explorer = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
Check "Explorer shows the full path in its title bar" { (Get-ItemPropertyValue -LiteralPath "$explorer\CabinetState" -Name FullPath -ErrorAction Stop) -eq 1 }
Check "Quick Access hides frequent folders"           { (Get-ItemPropertyValue -LiteralPath $explorer -Name ShowFrequent -ErrorAction Stop) -eq 0 }
Check "Taskbar End Task is enabled"                   { (Get-ItemPropertyValue -LiteralPath "$explorer\Advanced\TaskbarDeveloperSettings" -Name TaskbarEndTask -ErrorAction Stop) -eq 1 }

# WSL & VM platform
Check "wsl --version succeeds"                    { (wsl --version 2>$null) -ne $null }
Check "vmcompute service registered"              { (Get-Service vmcompute -ErrorAction SilentlyContinue) -ne $null }
Check "wsl lists Ubuntu"                          { (wsl -l -v 2>$null) -match 'Ubuntu' }
Check "wsl lsb_release shows Ubuntu"              { (wsl -- lsb_release -d 2>$null) -match '^Description:\s+Ubuntu' }
Check "wsl lsb_release shows Ubuntu 24.04"        { (wsl -- lsb_release -rs 2>$null) -match '^24\.04' }

# Git
Check "git --version succeeds"                    { (git --version 2>$null) -ne $null }
Check "git resolves under Program Files\Git"      { (where.exe git 2>$null) -match 'C:\\Program Files\\Git' }

# GitHub CLI
Check "gh --version succeeds"                     { (gh --version 2>$null) -ne $null }

# VS Code
Check "code --version succeeds"                   { (code --version 2>$null) -ne $null }

# .NET SDK
Check "dotnet --version starts with 10."          { (dotnet --version 2>$null) -match '^10\.' }

# Python & uv
Check "python --version starts with 3.14"         { (python --version 2>$null) -match '3\.14\.' }
Check "uv --version succeeds"                     { (uv --version 2>$null) -ne $null }

# Node lives in WSL2 now -- the in-distro checks belong to the WSL Vibe Coding script.

# Oh My Posh
Check "oh-my-posh --version succeeds"             { (oh-my-posh --version 2>$null) -ne $null }

Write-Host ""
Write-Host "Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })

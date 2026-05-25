# GitHub Team Stats — Windows installer
# Run in PowerShell: irm .../install.ps1 | iex
# Or: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/KvaddeML919/github-analytics-service.git"
$InstallDir = Join-Path $env:USERPROFILE "github-stats"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Shortcut = Join-Path $Desktop "GitHub Stats.bat"

function Write-InstallError {
    param([string]$Message, [string]$Recovery = "")
    Write-Host ""
    Write-Host "Error: $Message" -ForegroundColor Red
    if ($Recovery) { Write-Host $Recovery }
    exit 1
}

function Find-Python {
    $candidates = @(
        @{ Exe = "py"; Args = @("-3") },
        @{ Exe = "python"; Args = @() },
        @{ Exe = "python3"; Args = @() }
    )
    foreach ($c in $candidates) {
        if (Get-Command $c.Exe -ErrorAction SilentlyContinue) {
            return $c
        }
    }
    return $null
}

function Invoke-Python {
    param([string[]]$PythonArgs)
    $script:Py = if ($script:Py) { $script:Py } else { Find-Python }
    if (-not $script:Py) {
        Write-InstallError "Python 3 not found." @"
  Install from https://www.python.org/downloads/
  During setup, check 'Add python.exe to PATH', then re-run this installer.
"@
    }
    if ($script:Py.Args.Count -gt 0) {
        & $script:Py.Exe @($script:Py.Args + $PythonArgs)
    } else {
        & $script:Py.Exe @PythonArgs
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Show-ManualRecovery {
    Write-Host "  Manual recovery:"
    Write-Host "    cd $InstallDir"
    Write-Host "    python -m pip install -r requirements.txt"
    Write-Host "    python -c ""import requests, openpyxl; print('OK')"""
    Write-Host "    python github_stats.py"
}

function Invoke-PythonAllowFail {
    param([string[]]$PythonArgs)
    if ($script:Py.Args.Count -gt 0) {
        & $script:Py.Exe @($script:Py.Args + $PythonArgs)
    } else {
        & $script:Py.Exe @PythonArgs
    }
    return $LASTEXITCODE
}

function Install-Dependencies {
    Push-Location $InstallDir

    Write-Host "Installing Python dependencies..."
    $pipExit = Invoke-PythonAllowFail @("-m", "pip", "install", "--user", "-r", "requirements.txt")
    if ($pipExit -ne 0) {
        Write-Host "  Note: --user install failed; retrying without --user ..."
        $pipExit = Invoke-PythonAllowFail @("-m", "pip", "install", "-r", "requirements.txt")
    }
    if ($pipExit -ne 0) {
        Pop-Location
        Write-Host ""
        Write-Host "Error: Failed to install Python dependencies (see pip output above)." -ForegroundColor Red
        Show-ManualRecovery
        exit 1
    }

    Write-Host "Verifying dependencies..."
    $verifyExit = Invoke-PythonAllowFail @("-c", "import requests, openpyxl; print('  Dependencies OK')")
    if ($verifyExit -ne 0) {
        Pop-Location
        Write-Host ""
        Write-Host "Error: Dependencies installed but import check failed." -ForegroundColor Red
        Show-ManualRecovery
        exit 1
    }

    Pop-Location
}

Write-Host ""
Write-Host "========================================="
Write-Host "  GitHub Team Stats — Installer (Windows)"
Write-Host "========================================="
Write-Host ""

# --- Preflight checks ---
Write-Host "Checking prerequisites..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-InstallError "Git is not installed or not on PATH." @"
  Install Git for Windows: https://git-scm.com/download/win
  Restart PowerShell, then re-run this installer.
"@
}
Write-Host "  Git: OK"

$script:Py = Find-Python
if (-not $script:Py) {
    Write-InstallError "Python 3 not found." @"
  Install from https://www.python.org/downloads/
  During setup, check 'Add python.exe to PATH', then re-run this installer.
"@
}
$versionArgs = if ($script:Py.Args.Count -gt 0) { $script:Py.Args + @("--version") } else { @("--version") }
$pyVersion = & $script:Py.Exe @versionArgs 2>&1
Write-Host "  Python 3: OK ($pyVersion)"

Invoke-Python @("-m", "pip", "--version")
Write-Host "  pip: OK"

Write-Host ""

# --- Clone or update ---
if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "Updating existing installation..."
    Push-Location $InstallDir
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-InstallError "git pull failed." "  Check your network and try again." }
    Pop-Location
} elseif (Test-Path $InstallDir) {
    Write-InstallError "$InstallDir exists but is not a git repo." @"
  Remove the folder and re-run this installer:
    Remove-Item -Recurse -Force "$InstallDir"
"@
} else {
    Write-Host "Cloning repository..."
    git clone $RepoUrl $InstallDir
    if ($LASTEXITCODE -ne 0) { Write-InstallError "git clone failed." "  Check your network and Git installation." }
}

Write-Host ""

Install-Dependencies

Write-Host ""

# --- org.txt ---
$OrgFile = Join-Path $InstallDir "org.txt"
if (-not (Test-Path $OrgFile)) {
    $orgName = Read-Host "Enter the GitHub organization name"
    if ([string]::IsNullOrWhiteSpace($orgName)) {
        Write-InstallError "No organization name provided."
    }
    Set-Content -Path $OrgFile -Value $orgName.Trim()
    Write-Host "Saved org: $orgName"
} else {
    $existing = Get-Content $OrgFile -Raw
    Write-Host "org.txt already exists — keeping existing org: $($existing.Trim())"
}

Write-Host ""

# --- team.txt ---
$TeamFile = Join-Path $InstallDir "team.txt"
if (-not (Test-Path $TeamFile)) {
    Write-Host "Setting up teams and members..."
    Write-Host "You'll enter team names first, then GitHub usernames for each team."
    Write-Host "Press Enter on an empty line to finish each step."
    Write-Host ""
    Set-Content -Path $TeamFile -Value ""
    $totalMembers = 0

    while ($true) {
        $teamName = Read-Host "  Team name (empty to finish adding teams)"
        if ([string]::IsNullOrWhiteSpace($teamName)) { break }

        Add-Content -Path $TeamFile -Value "[$teamName]"
        Write-Host "    Adding members to $teamName..."

        $teamCount = 0
        while ($true) {
            $username = Read-Host "      Username (empty to finish this team)"
            if ([string]::IsNullOrWhiteSpace($username)) { break }
            Add-Content -Path $TeamFile -Value $username.Trim()
            $teamCount++
            $totalMembers++
        }
        Add-Content -Path $TeamFile -Value ""
        Write-Host "    Added $teamCount member(s) to $teamName."
        Write-Host ""
    }

    if ($totalMembers -eq 0) {
        Write-Host ""
        Write-Host "Warning: No members added. Edit $TeamFile before running."
    } else {
        Write-Host ""
        Write-Host "Added $totalMembers total team member(s)."
    }
} else {
    Write-Host "team.txt already exists — keeping existing team list."
}

Write-Host ""

# --- Desktop launcher ---
$py = $script:Py
$pyCmd = if ($py.Args.Count -gt 0) { "$($py.Exe) $($py.Args -join ' ')" } else { $py.Exe }

$batContent = @"
@echo off
cd /d "%USERPROFILE%\github-stats"
if errorlevel 1 (
    echo Error: %%USERPROFILE%%\github-stats not found. Re-run the installer.
    pause
    exit /b 1
)
echo.
echo =========================================
echo   GitHub Team Stats
echo =========================================
echo.
$pyCmd -c "import requests, openpyxl" 2>nul
if errorlevel 1 (
    echo Error: Missing dependencies. Run in PowerShell:
    echo   cd %%USERPROFILE%%\github-stats
    echo   $pyCmd -m pip install -r requirements.txt
    pause
    exit /b 1
)
$pyCmd github_stats.py
echo.
echo -----------------------------------------
pause
"@

Set-Content -Path $Shortcut -Value $batContent -Encoding ASCII
Write-Host "Desktop shortcut created: GitHub Stats.bat"
Write-Host ""
Write-Host "========================================="
Write-Host "  Installation complete!"
Write-Host "========================================="
Write-Host ""
Write-Host "  To run:  Double-click 'GitHub Stats.bat' on your Desktop"
Write-Host "  To edit team list:  $TeamFile"
Write-Host ""

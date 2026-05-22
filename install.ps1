# GitHub Team Stats — Windows installer
# Run in PowerShell: irm .../install.ps1 | iex
# Or: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/KvaddeML919/github-analytics-service.git"
$InstallDir = Join-Path $env:USERPROFILE "github-stats"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Shortcut = Join-Path $Desktop "GitHub Stats.bat"

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
    $py = Find-Python
    if (-not $py) {
        Write-Host ""
        Write-Host "Error: Python 3 not found. Install from https://www.python.org/downloads/"
        Write-Host "  During setup, check 'Add python.exe to PATH'."
        exit 1
    }
    if ($py.Args.Count -gt 0) {
        & $py.Exe @($py.Args + $PythonArgs)
    } else {
        & $py.Exe @PythonArgs
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "========================================="
Write-Host "  GitHub Team Stats — Installer (Windows)"
Write-Host "========================================="
Write-Host ""

# --- Git check ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is not installed or not on PATH."
    Write-Host "  Install Git for Windows: https://git-scm.com/download/win"
    exit 1
}

# --- Clone or update ---
if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "Updating existing installation..."
    Push-Location $InstallDir
    git pull --ff-only
    Pop-Location
} elseif (Test-Path $InstallDir) {
    Write-Host "Error: $InstallDir exists but is not a git repo."
    Write-Host "Remove it and re-run this installer."
    exit 1
} else {
    Write-Host "Cloning repository..."
    git clone $RepoUrl $InstallDir
}

Write-Host ""

# --- Python dependencies ---
Write-Host "Installing Python dependencies..."
Push-Location $InstallDir
try {
    Invoke-Python @("-m", "pip", "install", "--user", "-r", "requirements.txt")
} catch {
    Invoke-Python @("-m", "pip", "install", "-r", "requirements.txt")
}
Pop-Location
Write-Host ""

# --- org.txt ---
$OrgFile = Join-Path $InstallDir "org.txt"
if (-not (Test-Path $OrgFile)) {
    $orgName = Read-Host "Enter the GitHub organization name"
    if ([string]::IsNullOrWhiteSpace($orgName)) {
        Write-Host "Error: No organization name provided."
        exit 1
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
$py = Find-Python
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

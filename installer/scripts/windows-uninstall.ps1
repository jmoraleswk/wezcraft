# WezTerm Uninstaller (Windows)
# Usage: .\scripts\windows-uninstall.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== WezTerm Uninstaller (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Prompt: remove config ---
$Answer = Read-Host "Remove ~/.config/wezterm/? [y/N]"
if ($Answer -match '^[Yy]$') {
    $Target = Join-Path $env:USERPROFILE ".config\wezterm"
    if (Test-Path $Target) {
        Remove-Item -Recurse -Force $Target
        Write-Host "  Removed ~/.config/wezterm/"
    }
}

# --- 2. Prompt: remove session saves ---
$Answer = Read-Host "Remove session saves? [y/N]"
if ($Answer -match '^[Yy]$') {
    $SavesDir = "$env:LOCALAPPDATA\wezterm"
    if (Test-Path $SavesDir) {
        Remove-Item -Recurse -Force $SavesDir
        Write-Host "  Removed session saves"
    }
}

# --- 3. Prompt: remove font ---
$Answer = Read-Host "Remove FiraCode Nerd Font? [y/N]"
if ($Answer -match '^[Yy]$') {
    $FontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $FontFile = "FiraCodeNerdFont-Regular.ttf"
    if (Test-Path "$FontDir\$FontFile") {
        Remove-Item -Force "$FontDir\$FontFile"
        Write-Host "  Removed FiraCode Nerd Font"
    }
}

# --- 4. Prompt: remove Starship ---
$StarshipPath = Get-Command starship -ErrorAction SilentlyContinue
if ($StarshipPath) {
    $Answer = Read-Host "Remove Starship? [y/N]"
    if ($Answer -match '^[Yy]$') {
        winget uninstall -e Starship.Starship
        Write-Host "  Removed Starship"
    }
}

# --- 5. Prompt: remove Starship config ---
$StarshipConfig = Join-Path $env:USERPROFILE ".config\starship.toml"
if (Test-Path $StarshipConfig) {
    $Answer = Read-Host "Remove Starship config (~/.config/starship.toml)? [y/N]"
    if ($Answer -match '^[Yy]$') {
        Remove-Item -Force $StarshipConfig
        Write-Host "  Removed Starship config"
    }
}

# --- 6. Prompt: remove Atuin ---
$AtuinPath = Get-Command atuin -ErrorAction SilentlyContinue
if ($AtuinPath) {
    $Answer = Read-Host "Remove Atuin? [y/N]"
    if ($Answer -match '^[Yy]$') {
        winget uninstall -e Atuinsh.Atuin
        Write-Host "  Removed Atuin"
    }
}

# --- 7. Prompt: remove backups ---
$BackupDir = Join-Path $env:USERPROFILE ".config"
$Backups = Get-ChildItem -Path $BackupDir -Filter "wezterm.bak.*" -Directory -ErrorAction SilentlyContinue
if ($Backups.Count -gt 0) {
    Write-Host "Found $($Backups.Count) backup(s):"
    $Backups | ForEach-Object { Write-Host "  $($_.FullName)" }
    $Answer = Read-Host "Remove all backups? [y/N]"
    if ($Answer -match '^[Yy]$') {
        $Backups | Remove-Item -Recurse -Force
        Write-Host "  Removed backups"
    }
}

Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Green

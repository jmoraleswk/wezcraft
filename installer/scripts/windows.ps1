# WezTerm Installer (Windows)
# Usage: .\scripts\windows.ps1 [-Source <path>]

param(
    [string]$Source
)

$ErrorActionPreference = "Stop"

Write-Host "=== WezTerm Installer (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Determine source ---
if (-not $Source) {
    # Clone from GitHub
    $RepoUrl = "https://github.com/jmoraleswk/wezcraft"
    $TempDir = Join-Path $env:TEMP "wezcraft-install"
    
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }
    
    Write-Host "Cloning from: $RepoUrl"
    git clone --depth 1 $RepoUrl $TempDir 2>$null
    $Source = $TempDir
}

if (-not (Test-Path $Source)) {
    Write-Host "Error: Source directory not found: $Source" -ForegroundColor Red
    exit 1
}

# --- 2. Define target ---
$Target = Join-Path $env:USERPROFILE ".config\wezterm"

# --- 3. Backup existing config ---
if (Test-Path $Target) {
    $Backup = "$Target.bak.$(Get-Date -UFormat %s)"
    Write-Host "Backing up existing config -> $Backup"
    Move-Item -Path $Target -Destination $Backup
}

# --- 4. Copy config ---
Write-Host "Copying config files..."
New-Item -ItemType Directory -Force -Path $Target | Out-Null

$Exclude = @('.git', '.gitignore', '.DS_Store', '.atl', 'codebase', 'installer', 'docs', 'README.md')

Get-ChildItem -Path $Source -Exclude $Exclude | ForEach-Object {
    $Dest = Join-Path $Target $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Path $_.FullName -Destination $Dest -Recurse -Force
    } else {
        Copy-Item -Path $_.FullName -Destination $Dest -Force
    }
}

# --- 5. Create required directories ---
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\wezterm\resurrect" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\wezterm\state" | Out-Null

# --- 6. Install font ---
Write-Host ""
Write-Host "Installing FiraCode Nerd Font..."
$FontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

$FontFile = "FiraCodeNerdFont-Regular.ttf"
$FontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz"

if (-not (Test-Path "$FontDir\$FontFile")) {
    $TempFont = Join-Path $env:TEMP "FiraCode.tar.xz"
    $TempExtract = Join-Path $env:TEMP "FiraCode-extract"
    Write-Host "Downloading font..."
    Invoke-WebRequest -Uri $FontUrl -OutFile $TempFont
    
    # Extract tar.xz
    if (Test-Path $TempExtract) {
        Remove-Item -Recurse -Force $TempExtract
    }
    New-Item -ItemType Directory -Force -Path $TempExtract | Out-Null
    
    Write-Host "Extracting font..."
    tar -xf $TempFont -C $TempExtract 2>$null
    
    # Copy TTF files to font directory
    $TtfFiles = Get-ChildItem -Path $TempExtract -Filter "*.ttf" -Recurse
    if ($TtfFiles) {
        foreach ($Ttf in $TtfFiles) {
            Copy-Item -Path $Ttf.FullName -Destination $FontDir -Force
        }
        Write-Host "FiraCode Nerd Font installed."
    } else {
        Write-Host "Warning: No TTF files found in archive." -ForegroundColor Yellow
        Write-Host "  Please extract manually from: $TempFont"
    }
    
    # Cleanup
    Remove-Item -Recurse -Force $TempExtract -ErrorAction SilentlyContinue
} else {
    Write-Host "FiraCode Nerd Font already installed."
}

# --- 7. Install Starship prompt ---
Write-Host ""
$StarshipInstalled = Get-Command starship -ErrorAction SilentlyContinue
if ($StarshipInstalled) {
    Write-Host "Starship already installed: $(starship --version | Select-Object -First 1)"
} else {
    $InstallStarship = Read-Host "Install Starship prompt? [Y/n]"
    if ($InstallStarship -match '^[Yy]?$') {
        Write-Host "Installing Starship..."
        winget install -e Starship.Starship
        Write-Host "Starship installed."
    }
}

# --- 8. Starship config ---
$StarshipConfig = Join-Path $env:USERPROFILE ".config\starship.toml"
if (-not (Test-Path $StarshipConfig)) {
    Write-Host "Creating default Starship config..."
    New-Item -ItemType Directory -Force -Path (Split-Path $StarshipConfig) | Out-Null
    
    @"
# Starship config for WezCraft
format = """
`$directory\
`$git_branch\
`$git_status\
`$nodejs\
`$lua\
`$docker_context\
`$shell\
`$character"""

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "

[git_status]
deleted = "✘"
ahead = "⇡`${count}"
behind = "⇣`${count}"
diverged = "⇡`${count}⇣`${count}"

[nodejs]
symbol = " "

[lua]
symbol = " "

[docker_context]
symbol = " "

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"
"@ | Out-File -FilePath $StarshipConfig -Encoding UTF8
    Write-Host "Starship config created at: $StarshipConfig"
}

# --- 9. Install Atuin ---
Write-Host ""
$AtuinInstalled = Get-Command atuin -ErrorAction SilentlyContinue
if ($AtuinInstalled) {
    Write-Host "Atuin already installed: $(atuin --version)"
} else {
    $InstallAtuin = Read-Host "Install Atuin (shell history)? [Y/n]"
    if ($InstallAtuin -match '^[Yy]?$') {
        Write-Host "Installing Atuin..."
        winget install -e Atuinsh.Atuin
        Write-Host "Atuin installed."
    }
}

# --- 10. Shell integration ---
Write-Host ""

# Ensure PowerShell profile exists
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

# Starship
$StarshipPath = Get-Command starship -ErrorAction SilentlyContinue
if ($StarshipPath) {
    $ProfileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "starship init") {
        Write-Host "Adding Starship to PowerShell profile..."
        'Invoke-Expression (&starship init powershell)' | Out-File -FilePath $PROFILE -Append -Encoding UTF8
    }
}

# Atuin
$AtuinPath = Get-Command atuin -ErrorAction SilentlyContinue
if ($AtuinPath) {
    $ProfileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "atuin init") {
        Write-Host "Adding Atuin to PowerShell profile..."
        'atuin init powershell | Out-String | Invoke-Expression' | Out-File -FilePath $PROFILE -Append -Encoding UTF8
    }
}

# --- 11. Summary ---
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Config installed to: $Target"
Write-Host "Plugin: resurrect.wezterm (bundled)"
if ($StarshipInstalled) {
    Write-Host "Starship: installed"
}
if ($AtuinInstalled) {
    Write-Host "Atuin: installed"
}
Write-Host ""
Write-Host "Note: Stats daemon (CPU/RAM) is not available on Windows."
Write-Host "Restart your terminal to apply changes."

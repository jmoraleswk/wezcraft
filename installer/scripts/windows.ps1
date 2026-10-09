# WezTerm Installer (Windows)
# Usage: .\scripts\windows.ps1 [-Source <path>]
#
# Shared logic lives in wezcraft-win.ps1 (dot-sourced below), the Windows
# analogue of pkg.sh: native-command exit-code capture, failure collection, the
# install log, per-component progress, and the end-of-run summary are owned
# there, once. Every path tests must inject is a parameter whose default is the
# value this script used to hardcode, so a bare `.\windows.ps1` behaves as before.

param(
    [string]$Source,
    [string]$Target = (Join-Path $env:USERPROFILE ".config\wezterm"),
    [string]$FontDir = (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"),
    # Pinned font source: the same FiraCode.zip release and checksum that
    # pkg.sh verifies on macOS/Linux. Bump both together.
    [string]$FontUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FiraCode.zip',
    [string]$FontSha256 = '239395baf60c89b2eaf4862b6b09db0ef95605cd3e8eef51c00345822a81a665',
    [string]$TempRoot = $env:TEMP,
    [string]$TaskName = "WezTermStats",
    [string]$LogFile = (Join-Path $env:TEMP "wezcraft-install.log"),
    [string]$StateFile = (Join-Path $env:LOCALAPPDATA 'wezcraft\installed-state'),
    [string]$ProfilePath
)

$ErrorActionPreference = "Stop"

# Resolve the profile only after binding: defaulting it to $PROFILE inside the
# param block is fragile under constrained / automation hosts.
if (-not $ProfilePath) {
    $ProfilePath = $PROFILE
}

. (Join-Path $PSScriptRoot "wezcraft-win.ps1")

$TotalComponents = 6

Write-Host "=== WezTerm Installer (Windows) ===" -ForegroundColor Cyan
Write-InstallLog -LogFile $LogFile -Message "=== WezTerm Installer (Windows) started ==="

# --- 1. Config: source, backup, copy, required directories ---
Start-InstallComponent -Index 1 -Total $TotalComponents -Name "config" -LogFile $LogFile

$CloneFailed = $false
if (-not $Source) {
    # Clone from GitHub
    $RepoUrl = "https://github.com/jmoraleswk/wezcraft"
    $TempDir = Join-Path $TempRoot "wezcraft-install"

    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }

    Write-Host "Cloning from: $RepoUrl"
    if (Invoke-CheckedNative -Label "config" -Command { git clone --depth 1 $RepoUrl $TempDir } -LogFile $LogFile) {
        $Source = $TempDir
        Add-InstallState -StateFile $StateFile -Entry "win:path:$TempDir"
    } else {
        # The helper already recorded the clone as this run's failure; do not
        # record a second entry for the same root cause below.
        $CloneFailed = $true
    }
}

if (-not (Test-Path $Source)) {
    Write-Host "Error: Source directory not found: $Source" -ForegroundColor Red
    Write-InstallLog -LogFile $LogFile -Level "ERROR" -Message "source directory not found: $Source"
    if (-not $CloneFailed) {
        # Only record a missing source when it is not the clone we just logged.
        Add-InstallFailure -Component "config" -Message "source directory not found: $Source"
    }
    # Nothing to install from: finish through the honest summary instead of
    # returning a silent success.
    exit (Show-InstallSummary -LogFile $LogFile)
}

# Backup existing config
if (Test-Path $Target) {
    $Backup = "$Target.bak.$(Get-Date -UFormat %s)"
    Write-Host "Backing up existing config -> $Backup"
    Move-Item -Path $Target -Destination $Backup
}

# Copy config
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

# Create required directories
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\wezterm\resurrect" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\wezterm\state" | Out-Null

Write-InstallLog -LogFile $LogFile -Message "config installed to $Target"

# --- 2. Install font ---
Start-InstallComponent -Index 2 -Total $TotalComponents -Name "font" -LogFile $LogFile
Write-Host "Installing FiraCode Nerd Font..."
New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

$FontFile = "FiraCodeNerdFont-Regular.ttf"

if (-not (Test-Path "$FontDir\$FontFile")) {
    $TempFont = Join-Path $TempRoot 'FiraCode.zip'
    Write-Host 'Downloading pinned font archive (v3.5.1)...'
    $DownloadOk = Save-FontArchive -Url $FontUrl -OutFile $TempFont -LogFile $LogFile

    if ($DownloadOk) {
        $FontOk = Install-FontArchive -ArchivePath $TempFont -ExpectedSha256 $FontSha256 -FontDir $FontDir -ExtractRoot $TempRoot -StateFile $StateFile -LogFile $LogFile
        if ($FontOk) {
            Write-Host 'FiraCode Nerd Font installed and registered.'
        }
    }

    # Cleanup: the downloaded archive is never left behind.
    Remove-Item -Path $TempFont -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "FiraCode Nerd Font already installed."
    Write-InstallLog -LogFile $LogFile -Message "font already installed"
}

# --- 3. Install Starship prompt ---
Start-InstallComponent -Index 3 -Total $TotalComponents -Name "starship" -LogFile $LogFile
$StarshipInstalled = Get-Command starship -ErrorAction SilentlyContinue
if ($StarshipInstalled) {
    Write-Host "Starship already installed: $(starship --version | Select-Object -First 1)"
    Write-InstallLog -LogFile $LogFile -Message "starship already installed"
} else {
    $InstallStarship = Read-Host "Install Starship prompt? [Y/n]"
    if ($InstallStarship -match '^[Yy]?$') {
        Write-Host "Installing Starship..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            if (Invoke-CheckedNative -Label "starship" -Command { winget install -e Starship.Starship } -LogFile $LogFile) {
                Write-Host "Starship installed."
                # Owned only when WE installed it: a pre-existing starship is
                # never ours to uninstall (I3).
                Add-InstallState -StateFile $StateFile -Entry 'win:winget:Starship.Starship'
            }
        } else {
            Add-InstallFailure -Component "starship" -Message "winget is not available; install Starship manually from https://starship.rs"
            Write-Host "  [FAIL] winget is not available; cannot install Starship." -ForegroundColor Red
            Write-Host "    Install it manually: https://starship.rs" -ForegroundColor Red
            Write-InstallLog -LogFile $LogFile -Level "ERROR" -Message "winget not available; starship not installed"
        }
    } else {
        Write-InstallLog -LogFile $LogFile -Message "starship installation declined by user"
    }
}

# --- Starship config (part of the starship component) ---
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
    Write-InstallLog -LogFile $LogFile -Message "starship config created at $StarshipConfig"
    Add-InstallState -StateFile $StateFile -Entry "win:path:$StarshipConfig"
}

# --- 4. Install Atuin ---
Start-InstallComponent -Index 4 -Total $TotalComponents -Name "atuin" -LogFile $LogFile
$AtuinInstalled = Get-Command atuin -ErrorAction SilentlyContinue
if ($AtuinInstalled) {
    Write-Host "Atuin already installed: $(atuin --version)"
    Write-InstallLog -LogFile $LogFile -Message "atuin already installed"
} else {
    $InstallAtuin = Read-Host "Install Atuin (shell history)? [Y/n]"
    if ($InstallAtuin -match '^[Yy]?$') {
        Write-Host "Installing Atuin..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            if (Invoke-CheckedNative -Label "atuin" -Command { winget install -e Atuinsh.Atuin } -LogFile $LogFile) {
                Write-Host "Atuin installed."
                Add-InstallState -StateFile $StateFile -Entry 'win:winget:Atuinsh.Atuin'
            }
        } else {
            Add-InstallFailure -Component "atuin" -Message "winget is not available; install Atuin manually from https://atuin.sh"
            Write-Host "  [FAIL] winget is not available; cannot install Atuin." -ForegroundColor Red
            Write-Host "    Install it manually: https://atuin.sh" -ForegroundColor Red
            Write-InstallLog -LogFile $LogFile -Level "ERROR" -Message "winget not available; atuin not installed"
        }
    } else {
        Write-InstallLog -LogFile $LogFile -Message "atuin installation declined by user"
    }
}

# --- 5. Shell integration ---
Start-InstallComponent -Index 5 -Total $TotalComponents -Name "shell integration" -LogFile $LogFile

# Ensure PowerShell profile exists
if (-not (Test-Path $ProfilePath)) {
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
}

# Starship
$StarshipPath = Get-Command starship -ErrorAction SilentlyContinue
if ($StarshipPath) {
    $ProfileContent = Get-Content $ProfilePath -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "starship init") {
        Write-Host "Adding Starship to PowerShell profile..."
        $WezCraftStarshipProfileLine | Out-File -FilePath $ProfilePath -Append -Encoding UTF8
        Add-InstallState -StateFile $StateFile -Entry 'win:profile:starship-init'
    }
}

# Atuin
$AtuinPath = Get-Command atuin -ErrorAction SilentlyContinue
if ($AtuinPath) {
    $ProfileContent = Get-Content $ProfilePath -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "atuin init") {
        Write-Host "Adding Atuin to PowerShell profile..."
        $WezCraftAtuinProfileLine | Out-File -FilePath $ProfilePath -Append -Encoding UTF8
        Add-InstallState -StateFile $StateFile -Entry 'win:profile:atuin-init'
    }
}

Write-InstallLog -LogFile $LogFile -Message "shell integration applied to $ProfilePath"

# --- 6. Stats daemon (Task Scheduler) ---
Start-InstallComponent -Index 6 -Total $TotalComponents -Name "stats daemon" -LogFile $LogFile
Write-Host "Installing stats daemon (CPU/RAM)..."

$StatsScript = Join-Path $Target "elements\statusbar\update_stats_windows.ps1"

# Remove existing task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Create scheduled task to run at user logon
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$StatsScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Force | Out-Null

# Start the task immediately
Start-ScheduledTask -TaskName $TaskName

Write-Host "Stats daemon installed and started."
Write-Host "Task: $TaskName (runs at logon)"
Write-InstallLog -LogFile $LogFile -Message "stats daemon installed and started (task $TaskName)"
Add-InstallState -StateFile $StateFile -Entry "win:task:$TaskName"
# update_stats_windows.ps1 writes its file here; own the path so the
# uninstaller can remove the artifact the daemon produces.
Add-InstallState -StateFile $StateFile -Entry "win:path:$(Join-Path $TempRoot 'wezterm_stats.txt')"

# --- 7. Summary ---
$ExitCode = Show-InstallSummary -LogFile $LogFile

# Never print positive claims on a failed run: a red failure list followed by
# "active"/"installed" would misreport the outcome. The success text is gated
# on the summary's result; the exit code is always the summary's.
if ($ExitCode -eq 0) {
    Write-Host "Config installed to: $Target"
    Write-Host "Plugin: resurrect.wezterm (bundled)"
    Write-Host "Font: FiraCode Nerd Font"
    if ($StarshipInstalled) {
        Write-Host "Starship: installed"
    }
    if ($AtuinInstalled) {
        Write-Host "Atuin: installed"
    }
    Write-Host "Stats daemon: active (Task Scheduler)"
    Write-Host ""
    Write-Host "Restart your terminal to apply changes."
}
exit $ExitCode

# WezTerm Uninstaller (Windows)
# Usage: .\scripts\windows-uninstall.ps1
#
# Every removal is gated on the install state written by windows.ps1
# (%LOCALAPPDATA%\wezcraft\installed-state): this script removes ONLY what
# that state says WezCraft installed, so a starship, font, or profile line
# the user already had is never touched (the fzf lesson). Prompts stay for
# the user-owned choices; declining keeps the entry and its state. The
# summary is honest: green only when the run is clean, and the exit code is
# always the summary's. Failure ExitCode: -6 removal failed.

param(
    [string]$Target = (Join-Path $env:USERPROFILE '.config\wezterm'),
    [string]$SavesDir = (Join-Path $env:LOCALAPPDATA 'wezterm'),
    [string]$FontDir = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
    [string]$TempRoot = $env:TEMP,
    [string]$TaskName = 'WezTermStats',
    [string]$StateFile = (Join-Path $env:LOCALAPPDATA 'wezcraft\installed-state'),
    [string]$ProfilePath,
    [string]$LogFile = (Join-Path $env:TEMP 'wezcraft-uninstall.log')
)

$ErrorActionPreference = 'Stop'

# Resolve the profile only after binding: defaulting it to $PROFILE inside
# the param block is fragile under constrained / automation hosts.
if (-not $ProfilePath) {
    $ProfilePath = $PROFILE
}

. (Join-Path $PSScriptRoot 'wezcraft-win.ps1')

$TotalSteps = 10

Write-Host '=== WezTerm Uninstaller (Windows) ===' -ForegroundColor Cyan
Write-Host ''
Write-InstallLog -LogFile $LogFile -Message '=== WezTerm Uninstaller (Windows) started ==='

$State = @(Get-InstallState -StateFile $StateFile)
if ($State.Count -eq 0) {
    Write-Host 'No install state: WezCraft installed nothing here; removing nothing.'
    exit (Show-InstallSummary -LogFile $LogFile)
}

# --- 1. Config (user-owned choice: the config may outlive the tooling) ---
Start-InstallComponent -Index 1 -Total $TotalSteps -Name 'config' -LogFile $LogFile
$Answer = Read-Host 'Remove ~/.config/wezterm/? [y/N]'
if ($Answer -match '^[Yy]$') {
    try {
        if (Test-Path $Target) {
            Remove-Item -Path $Target -Recurse -Force
            Write-Host '  Removed ~/.config/wezterm/'
        }
    } catch {
        Add-InstallFailure -Component 'config' -Message "removal failed: $($_.Exception.Message)" -ExitCode -6
    }
}

# --- 2. Session saves (user-owned choice) ---
Start-InstallComponent -Index 2 -Total $TotalSteps -Name 'session saves' -LogFile $LogFile
$Answer = Read-Host 'Remove session saves? [y/N]'
if ($Answer -match '^[Yy]$') {
    try {
        if (Test-Path $SavesDir) {
            Remove-Item -Path $SavesDir -Recurse -Force
            Write-Host '  Removed session saves'
        }
    } catch {
        Add-InstallFailure -Component 'session saves' -Message "removal failed: $($_.Exception.Message)" -ExitCode -6
    }
}

# --- 3. Fonts: every font file and registry value the state says we own ---
Start-InstallComponent -Index 3 -Total $TotalSteps -Name 'fonts' -LogFile $LogFile
$FontEntries = @($State | Where-Object { $_ -like 'win:font:*' })
$HkcuEntries = @($State | Where-Object { $_ -like 'win:hkcu:*' })
if ($FontEntries.Count -gt 0 -or $HkcuEntries.Count -gt 0) {
    $Answer = Read-Host "Remove the $($FontEntries.Count) font file(s) WezCraft installed? [y/N]"
    if ($Answer -match '^[Yy]$') {
        foreach ($Entry in $FontEntries) {
            $FontPath = Join-Path $FontDir $Entry.Substring('win:font:'.Length)
            try {
                if (Test-Path $FontPath) {
                    Remove-Item -Path $FontPath -Force
                }
                Remove-InstallState -StateFile $StateFile -Entry $Entry
            } catch {
                Add-InstallFailure -Component 'fonts' -Message "removal failed for ${FontPath}: $($_.Exception.Message)" -ExitCode -6
            }
        }
        foreach ($Entry in $HkcuEntries) {
            $ValueName = $Entry.Substring('win:hkcu:'.Length)
            try {
                $Key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
                if (Get-ItemProperty -Path $Key -Name $ValueName -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $Key -Name $ValueName
                }
                Remove-InstallState -StateFile $StateFile -Entry $Entry
            } catch {
                Add-InstallFailure -Component 'fonts' -Message "registry removal failed for ${ValueName}: $($_.Exception.Message)" -ExitCode -6
            }
        }
        Write-Host "  Removed $($FontEntries.Count) font file(s), $($HkcuEntries.Count) registry value(s)"
    }
}

# --- 4. Starship: only when WE installed it via winget ---
Start-InstallComponent -Index 4 -Total $TotalSteps -Name 'starship' -LogFile $LogFile
if (Test-InstallState -StateFile $StateFile -Entry 'win:winget:Starship.Starship') {
    $Answer = Read-Host 'Remove Starship (installed by WezCraft)? [y/N]'
    if ($Answer -match '^[Yy]$') {
        if (Invoke-CheckedNative -Label 'starship' -Command { winget uninstall -e Starship.Starship } -LogFile $LogFile) {
            Remove-InstallState -StateFile $StateFile -Entry 'win:winget:Starship.Starship'
            Write-Host '  Removed Starship'
        }
    }
}

# --- 5. Starship config: only the file WE created ---
Start-InstallComponent -Index 5 -Total $TotalSteps -Name 'starship config' -LogFile $LogFile
$ConfigEntries = @($State | Where-Object { $_ -like 'win:path:*starship.toml' })
if ($ConfigEntries.Count -gt 0) {
    $Answer = Read-Host 'Remove Starship config (~/.config/starship.toml, created by WezCraft)? [y/N]'
    if ($Answer -match '^[Yy]$') {
        foreach ($Entry in $ConfigEntries) {
            $ConfigPath = $Entry.Substring('win:path:'.Length)
            try {
                if (Test-Path $ConfigPath) {
                    Remove-Item -Path $ConfigPath -Force
                }
                Remove-InstallState -StateFile $StateFile -Entry $Entry
                Write-Host '  Removed Starship config'
            } catch {
                Add-InstallFailure -Component 'starship config' -Message "removal failed for ${ConfigPath}: $($_.Exception.Message)" -ExitCode -6
            }
        }
    }
}

# --- 6. Atuin: only when WE installed it via winget ---
Start-InstallComponent -Index 6 -Total $TotalSteps -Name 'atuin' -LogFile $LogFile
if (Test-InstallState -StateFile $StateFile -Entry 'win:winget:Atuinsh.Atuin') {
    $Answer = Read-Host 'Remove Atuin (installed by WezCraft)? [y/N]'
    if ($Answer -match '^[Yy]$') {
        if (Invoke-CheckedNative -Label 'atuin' -Command { winget uninstall -e Atuinsh.Atuin } -LogFile $LogFile) {
            Remove-InstallState -StateFile $StateFile -Entry 'win:winget:Atuinsh.Atuin'
            Write-Host '  Removed Atuin'
        }
    }
}

# --- 7. Stats daemon: STOP before unregistering so no zombie survives ---
Start-InstallComponent -Index 7 -Total $TotalSteps -Name 'stats daemon' -LogFile $LogFile
$TaskEntries = @($State | Where-Object { $_ -like 'win:task:*' })
if ($TaskEntries.Count -gt 0) {
    $Answer = Read-Host 'Remove stats daemon (CPU/RAM)? [y/N]'
    if ($Answer -match '^[Yy]$') {
        foreach ($Entry in $TaskEntries) {
            $OwnedTask = $Entry.Substring('win:task:'.Length)
            try {
                if (Get-ScheduledTask -TaskName $OwnedTask -ErrorAction SilentlyContinue) {
                    Stop-ScheduledTask -TaskName $OwnedTask -ErrorAction SilentlyContinue
                    Unregister-ScheduledTask -TaskName $OwnedTask -Confirm:$false
                }
                Remove-InstallState -StateFile $StateFile -Entry $Entry
                Write-Host "  Removed stats daemon ($OwnedTask)"
            } catch {
                Add-InstallFailure -Component 'stats daemon' -Message "removal failed for task ${OwnedTask}: $($_.Exception.Message)" -ExitCode -6
            }
        }
    }
}

# --- 8. Shell integration: OUR lines, removed exactly -- no prompt ---
Start-InstallComponent -Index 8 -Total $TotalSteps -Name 'shell integration' -LogFile $LogFile
if ((Test-InstallState -StateFile $StateFile -Entry 'win:profile:starship-init') -or
    (Test-InstallState -StateFile $StateFile -Entry 'win:profile:atuin-init')) {
    try {
        if (Test-Path $ProfilePath) {
            $Kept = @(Get-Content -Path $ProfilePath | Where-Object {
                $_ -ne $WezCraftStarshipProfileLine -and $_ -ne $WezCraftAtuinProfileLine
            })
            if ($Kept.Count -gt 0) {
                Set-Content -Path $ProfilePath -Value $Kept -Encoding UTF8
            } else {
                Clear-Content -Path $ProfilePath
            }
        }
        Remove-InstallState -StateFile $StateFile -Entry 'win:profile:starship-init'
        Remove-InstallState -StateFile $StateFile -Entry 'win:profile:atuin-init'
        Write-Host "  Removed WezCraft shell integration from $ProfilePath"
    } catch {
        Add-InstallFailure -Component 'shell integration' -Message "removal failed: $($_.Exception.Message)" -ExitCode -6
    }
}

# --- 9. Temp files: owned paths under the temp root, removed automatically ---
Start-InstallComponent -Index 9 -Total $TotalSteps -Name 'temp files' -LogFile $LogFile
$PathEntries = @($State | Where-Object { $_ -like 'win:path:*' })
foreach ($Entry in $PathEntries) {
    $OwnedPath = $Entry.Substring('win:path:'.Length)
    # Safety net: whatever the state claims, never remove a path outside the
    # temp root here. Starship config is handled by its prompted section.
    if (-not $OwnedPath.StartsWith($TempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    try {
        if (Test-Path $OwnedPath) {
            Remove-Item -Path $OwnedPath -Recurse -Force
        }
        Remove-InstallState -StateFile $StateFile -Entry $Entry
    } catch {
        Add-InstallFailure -Component 'temp files' -Message "removal failed for ${OwnedPath}: $($_.Exception.Message)" -ExitCode -6
    }
}

# --- 10. Config backups (user-owned choice) ---
Start-InstallComponent -Index 10 -Total $TotalSteps -Name 'backups' -LogFile $LogFile
$BackupParent = Split-Path -Parent $Target
if ($BackupParent -and (Test-Path $BackupParent)) {
    $Backups = @(Get-ChildItem -Path $BackupParent -Filter 'wezterm.bak.*' -Directory -ErrorAction SilentlyContinue)
    if ($Backups.Count -gt 0) {
        $Answer = Read-Host "Remove the $($Backups.Count) config backup(s)? [y/N]"
        if ($Answer -match '^[Yy]$') {
            try {
                $Backups | Remove-Item -Recurse -Force
                Write-Host "  Removed $($Backups.Count) backup(s)"
            } catch {
                Add-InstallFailure -Component 'backups' -Message "removal failed: $($_.Exception.Message)" -ExitCode -6
            }
        }
    }
}

# Entries declined or failed stay in the state so a later run can finish.
$Remaining = @(Get-InstallState -StateFile $StateFile)
if ($Remaining.Count -gt 0) {
    Write-Host ''
    Write-Host 'Kept install state for entries not removed (declined or failed):' -ForegroundColor Yellow
    $Remaining | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

$ExitCode = Show-InstallSummary -LogFile $LogFile
exit $ExitCode

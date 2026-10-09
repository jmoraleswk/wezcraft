# wezcraft-win.ps1 - shared helpers for the WezCraft Windows installer family.
#
# Dot-sourced (NOT executed) by windows.ps1 and, later, windows-uninstall.ps1.
# This is the Windows analogue of installer/scripts/pkg.sh: the single owner of
# the logic both Windows scripts must share - native-command exit-code capture,
# failure collection, the install log, per-component progress, and the
# end-of-run summary. Defining any of this twice is exactly the drift this file
# exists to prevent.
#
# Public API:
#   Invoke-CheckedNative -Label <s> -Command <sb> [-LogFile <s>]
#                       run a native command, read its REAL exit code, and
#                       record a failure (with that exit code) on non-zero
#   Add-InstallFailure -Component <s> -Message <s> [-ExitCode <n>]
#   Get-InstallFailure  the failures recorded this run, in order
#   Clear-InstallFailure
#   Write-InstallLog -LogFile <s> -Message <s> [-Level <s>]
#   Start-InstallComponent -Index <n> -Total <n> -Name <s> [-LogFile <s>]
#   Show-InstallSummary [-LogFile <s>]   returns 0 when clean, 1 otherwise
#
# Load-time contract: defining these functions and initializing the failure
# list is the ONLY thing that happens when this file is dot-sourced. It never
# installs, prompts, exits, or writes to disk on its own.
#
# Why native-command capture lives here: `$ErrorActionPreference = "Stop"` does
# NOT turn a non-zero exit code of a native executable (git, tar, winget are
# all .exe) into a terminating error, so those failures silently continued and
# the installer still reported success. Invoke-CheckedNative reads
# `$LASTEXITCODE` directly and records the truth.

# Failure records for THIS run, in the order they were recorded. Plain objects
# (Component / Message / ExitCode) so the summary can report the real cause.
$script:WezCraftInstallFailures = @()

# The log path most recently written this run. The first write to a path
# truncates it so the install log cannot grow forever across runs; later writes
# to the same path append.
$script:WezCraftLogPath = $null

function Add-InstallFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [int]$ExitCode = 1
    )

    $script:WezCraftInstallFailures += [PSCustomObject]@{
        Component = $Component
        Message   = $Message
        ExitCode  = $ExitCode
    }
}

function Get-InstallFailure {
    [CmdletBinding()]
    param()

    return $script:WezCraftInstallFailures
}

function Clear-InstallFailure {
    [CmdletBinding()]
    param()

    $script:WezCraftInstallFailures = @()
}

# Append one timestamped line to the caller-supplied log path. The path is a
# parameter, never hardcoded here: the install scripts own where the log lives.
function Write-InstallLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Directory = Split-Path -Parent $LogFile
    if ($Directory -and -not (Test-Path -Path $Directory)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$Timestamp] [$Level] $Message"

    # Truncate on the first write to a path this run, then append. The installer
    # owns a single $LogFile per run, and Add-Content alone would otherwise grow
    # the log forever across runs.
    if ($script:WezCraftLogPath -ne $LogFile) {
        Set-Content -Path $LogFile -Value $Line -Encoding UTF8
        $script:WezCraftLogPath = $LogFile
    } else {
        Add-Content -Path $LogFile -Value $Line -Encoding UTF8
    }
}

# Run a native command and capture its REAL exit code. Output (stdout+stderr
# merged) is appended to $LogFile when one is given. Returns $true on exit code
# 0, $false otherwise (recording a failure either way).
function Invoke-CheckedNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [string]$LogFile
    )

    $ExitCode = 0
    $Exception = $null
    $Captured = @()
    $RawOutput = @()
    $MissingCommand = $null

    # A native executable reports failure through $LASTEXITCODE, which
    # $ErrorActionPreference = "Stop" does not escalate. Run with a local
    # Continue so redirected stderr cannot abort the call, then read the code.
    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $global:LASTEXITCODE = 0
        $RawOutput = @(& $Command 2>&1)
        $Captured = @($RawOutput | ForEach-Object { $_.ToString() })
        $ExitCode = $LASTEXITCODE
        # `&` on a command that is not on PATH raises a NON-terminating
        # CommandNotFoundException and leaves $LASTEXITCODE untouched, so the
        # exit code alone would report success for a binary that does not
        # exist. Detect that specific case by exception type, not message text.
        $MissingCommand = $RawOutput | Where-Object {
            $_ -is [System.Management.Automation.ErrorRecord] -and
            $_.Exception -is [System.Management.Automation.CommandNotFoundException]
        } | Select-Object -First 1
    } catch {
        $Exception = $_.Exception.Message
    } finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($LogFile) {
        foreach ($OutputLine in $Captured) {
            Write-InstallLog -LogFile $LogFile -Message "    $OutputLine"
        }
    }

    if ($Exception) {
        Add-InstallFailure -Component $Label -Message $Exception -ExitCode -1
        if ($LogFile) {
            Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "$Label threw: $Exception"
        }
        Write-Host "  [FAIL] $Label threw: $Exception" -ForegroundColor Red
        return $false
    }

    if ($MissingCommand) {
        $MissingName = $MissingCommand.Exception.CommandName
        if (-not $MissingName) {
            $MissingName = $Label
        }
        $MissingMessage = "command '$MissingName' was not found on PATH; install it or add it to PATH"
        Add-InstallFailure -Component $Label -Message $MissingMessage -ExitCode -1
        if ($LogFile) {
            Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "$Label failed: $MissingMessage"
        }
        Write-Host "  [FAIL] ${Label}: $MissingMessage" -ForegroundColor Red
        return $false
    }

    if ($ExitCode -ne 0) {
        Add-InstallFailure -Component $Label -Message "native command exited with code $ExitCode" -ExitCode $ExitCode
        if ($LogFile) {
            Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "$Label failed (exit code $ExitCode)"
        }
        Write-Host "  [FAIL] $Label (exit code $ExitCode)" -ForegroundColor Red
        return $false
    }

    if ($LogFile) {
        Write-InstallLog -LogFile $LogFile -Message "$Label succeeded"
    }
    return $true
}

# Per-component header, the Windows analogue of the bash side's
# pkg_run_component/show_progress: prints `[Index/Total] Name` and logs it.
function Start-InstallComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$LogFile
    )

    Write-Host ''
    Write-Host "[$Index/$Total] $Name" -ForegroundColor Cyan
    if ($LogFile) {
        Write-InstallLog -LogFile $LogFile -Message "===== component $Index/${Total}: $Name ====="
    }
}

# End-of-run summary. Prints the green "=== Done ===" ONLY when nothing failed;
# otherwise prints the red failure list (each failure plus the log path) and
# returns 1 so the caller exits non-zero. Returns the honest exit code.
function Show-InstallSummary {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    if ($script:WezCraftInstallFailures.Count -eq 0) {
        Write-Host ''
        Write-Host '=== Done ===' -ForegroundColor Green
        return 0
    }

    Write-Host ''
    Write-Host "=== Finished with $($script:WezCraftInstallFailures.Count) failure(s) ===" -ForegroundColor Red
    foreach ($Failure in $script:WezCraftInstallFailures) {
        Write-Host "  [FAIL] $($Failure.Component): $($Failure.Message) (exit code $($Failure.ExitCode))" -ForegroundColor Red
    }
    if ($LogFile) {
        Write-Host "  Log: $LogFile" -ForegroundColor Red
    }
    return 1
}

# SHA-256 of a file as hex. Lives here so the checksum path is testable
# against an externally computed constant instead of a re-statement.
function Get-FileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Get-FileHash returns uppercase hex; normalize so callers can compare
    # against pinned lowercase constants.
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Downloads a URL to a file. Records a failure and returns $false instead of
# throwing, so the caller keeps running through the honest summary.
# Failure ExitCodes: -4 download failed.
function Save-FontArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$OutFile,

        [string]$LogFile
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Message "downloaded font archive from $Url" }
        return $true
    } catch {
        Add-InstallFailure -Component 'font' -Message "font download failed: $($_.Exception.Message)" -ExitCode -4
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "font download failed: $($_.Exception.Message)" }
        Write-Host "  [FAIL] font download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Registers one font file for the current user: a REG_SZ under the per-user
# fonts key whose data is the FULL path (required for files outside
# %WinDir%\Fonts). Idempotent via -Force. Failure ExitCode: -2 registry write.
function Register-UserFont {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TtfPath,

        [string]$LogFile
    )

    $Key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $ValueName = '{0} (TrueType)' -f [System.IO.Path]::GetFileNameWithoutExtension($TtfPath)
    try {
        New-Item -Path $Key -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path $Key -Name $ValueName -Value $TtfPath -PropertyType String -Force -ErrorAction Stop | Out-Null
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Message "registered font $ValueName -> $TtfPath" }
        return $true
    } catch {
        Add-InstallFailure -Component 'font' -Message "registry write failed for ${ValueName}: $($_.Exception.Message)" -ExitCode -2
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "font registry write failed: $($_.Exception.Message)" }
        Write-Host "  [FAIL] font registry write failed for ${ValueName}" -ForegroundColor Red
        return $false
    }
}

# Verifies a font archive against the pinned SHA-256, extracts it, copies
# every .ttf into the user's font directory, and registers each one in HKCU.
# Bytes that cannot be verified are never installed: a checksum mismatch
# fails hard before extraction. The extraction directory is always removed.
# Failure ExitCodes: -3 checksum mismatch, -5 archive unusable.
function Install-FontArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedSha256,

        [Parameter(Mandatory = $true)]
        [string]$FontDir,

        [string]$ExtractRoot = $env:TEMP,

        [string]$LogFile
    )

    $ErrorActionPreference = 'Stop'

    $ActualSha256 = Get-FileSha256 -Path $ArchivePath
    if ($ActualSha256 -ne $ExpectedSha256) {
        Add-InstallFailure -Component 'font' -Message "SHA-256 mismatch: expected $ExpectedSha256, got $ActualSha256" -ExitCode -3
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message 'font archive checksum mismatch; nothing installed' }
        Write-Host '  [FAIL] font archive SHA-256 mismatch; nothing installed' -ForegroundColor Red
        return $false
    }

    $ExtractDir = Join-Path $ExtractRoot 'wezcraft-font-extract'
    try {
        if (Test-Path $ExtractDir) {
            Remove-Item -Path $ExtractDir -Recurse -Force
        }
        Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir

        $TtfFiles = @(Get-ChildItem -Path $ExtractDir -Filter '*.ttf' -Recurse)
        if ($TtfFiles.Count -eq 0) {
            Add-InstallFailure -Component 'font' -Message 'no TTF files in the verified archive' -ExitCode -5
            if ($LogFile) { Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message 'no TTF files in the font archive' }
            Write-Host '  [FAIL] no TTF files in the font archive' -ForegroundColor Red
            return $false
        }

        New-Item -ItemType Directory -Force -Path $FontDir | Out-Null
        foreach ($Ttf in $TtfFiles) {
            Copy-Item -Path $Ttf.FullName -Destination $FontDir -Force
            $Installed = Join-Path $FontDir $Ttf.Name
            if (-not (Register-UserFont -TtfPath $Installed -LogFile $LogFile)) {
                return $false
            }
        }
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Message "installed $($TtfFiles.Count) font files to $FontDir" }
        return $true
    } catch {
        Add-InstallFailure -Component 'font' -Message "font install failed: $($_.Exception.Message)" -ExitCode -5
        if ($LogFile) { Write-InstallLog -LogFile $LogFile -Level 'ERROR' -Message "font install failed: $($_.Exception.Message)" }
        Write-Host "  [FAIL] font install failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        if (Test-Path $ExtractDir) {
            Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Pester 5 tests for installer/scripts/windows-uninstall.ps1.
#
# The uninstaller is EXECUTED against injected fixtures: a fake config, font,
# temp, and profile tree under $TestDrive, a real (runner-ephemeral) HKCU
# value, and a real scheduled task the runner either permits or the test
# honestly skips. Real winget is NEVER executed: the tests prepend a fake
# winget.bat to PATH that only writes a marker file. Every prompt is mocked.

BeforeDiscovery {
    $OnWindows = ($env:OS -eq 'Windows_NT')
    if (-not $OnWindows) {
        Write-Host 'Skipping WindowsUninstaller.Tests.ps1: it requires Windows. CI runs it on windows-latest.'
    }
}

Describe 'windows-uninstall.ps1 gates every removal on the install state' -Skip:(-not $OnWindows) {
    BeforeAll {
        . "$PSScriptRoot/../scripts/wezcraft-win.ps1"
        $Uninstall = Join-Path $PSScriptRoot '../scripts/windows-uninstall.ps1'
        $HkcuKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        $HkcuValue = 'WezCraftUninstTest (TrueType)'

        # A real scheduled task on the runner; the full-removal test skips
        # with a clear message if the runner does not permit registration.
        $TaskName = 'WezCraftUninstTask'
        $Script:TaskReady = $true
        try {
            $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -Command exit'
            $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddDays(1)
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Force -ErrorAction Stop | Out-Null
        } catch {
            $Script:TaskReady = $false
            Write-Host "Register-ScheduledTask not permitted on this runner: $($_.Exception.Message)"
        }
    }

    AfterAll {
        Unregister-ScheduledTask -TaskName 'WezCraftUninstTask' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'WezCraftUninstTest (TrueType)' -ErrorAction SilentlyContinue
        Remove-Variable -Name WezCraftTestPrompts -Scope Global -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-InstallFailure
        # Global on purpose: a Pester mock body executes outside the test
        # file's scope chain, so $script: variables are invisible there.
        $global:WezCraftTestPrompts = [System.Collections.Generic.List[string]]::new()
    }

    It 'removes nothing and prompts nothing when the install state is empty' {
        # Pre-existing user data that must survive untouched (I3).
        $Root = Join-Path $TestDrive 's1'
        $Target = Join-Path $Root '.config/wezterm'
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        Set-Content -Path (Join-Path $Target 'wezterm.lua') -Value 'user config'
        $Fonts = Join-Path $Root 'fonts'
        New-Item -ItemType Directory -Force -Path $Fonts | Out-Null
        Set-Content -Path (Join-Path $Fonts 'PreExisting.ttf') -Value 'user font'
        $ProfileFile = Join-Path $Root 'profile.ps1'
        # A line that LOOKS like ours but was written by the user.
        Set-Content -Path $ProfileFile -Value $WezCraftStarshipProfileLine
        Mock Read-Host {
            $Text = "$Prompt"; if (-not $Text) { $Text = "$args" }
            [void]$global:WezCraftTestPrompts.Add($Text); 'y'
        }

        & $Uninstall -Target $Target -FontDir $Fonts -TempRoot (Join-Path $Root 'temp') -StateFile (Join-Path $Root 'state') -ProfilePath $ProfileFile -LogFile (Join-Path $Root 'uninstall.log') | Out-Null

        $LASTEXITCODE | Should -Be 0
        $global:WezCraftTestPrompts.Count | Should -Be 0
        Test-Path (Join-Path $Target 'wezterm.lua') | Should -BeTrue
        Test-Path (Join-Path $Fonts 'PreExisting.ttf') | Should -BeTrue
        (Get-Content -Path $ProfileFile -Raw) | Should -Match 'starship init'
    }

    It 'keeps owned files and their state when every prompted removal is declined' {
        $Root = Join-Path $TestDrive 's2'
        $Fonts = Join-Path $Root 'fonts'
        New-Item -ItemType Directory -Force -Path $Fonts | Out-Null
        Set-Content -Path (Join-Path $Fonts 'Keep.ttf') -Value 'owned font'
        $ProfileFile = Join-Path $Root 'profile.ps1'
        Set-Content -Path $ProfileFile -Value $WezCraftStarshipProfileLine
        $Temp = Join-Path $Root 'temp'
        New-Item -ItemType Directory -Force -Path $Temp | Out-Null
        $StatsFile = Join-Path $Temp 'wezterm_stats.txt'
        Set-Content -Path $StatsFile -Value 'stats'
        $State = Join-Path $Root 'state'
        Add-InstallState -StateFile $State -Entry 'win:font:Keep.ttf'
        Add-InstallState -StateFile $State -Entry 'win:profile:starship-init'
        Add-InstallState -StateFile $State -Entry "win:path:$StatsFile"
        Add-InstallState -StateFile $State -Entry 'win:task:WezTermStats'
        Mock Read-Host {
            $Text = "$Prompt"; if (-not $Text) { $Text = "$args" }
            [void]$global:WezCraftTestPrompts.Add($Text); 'n'
        }

        & $Uninstall -Target (Join-Path $Root '.config/wezterm') -SavesDir (Join-Path $Root 'saves') -FontDir $Fonts -TempRoot $Temp -StateFile $State -ProfilePath $ProfileFile -LogFile (Join-Path $Root 'uninstall.log') | Out-Null

        $LASTEXITCODE | Should -Be 0
        # Declined: owned files and their state survive.
        Test-Path (Join-Path $Fonts 'Keep.ttf') | Should -BeTrue
        Test-Path $StatsFile | Should -BeTrue
        $Remaining = @(Get-InstallState -StateFile $State)
        $Remaining | Should -Contain 'win:font:Keep.ttf'
        $Remaining | Should -Contain "win:path:$StatsFile"
        $Remaining | Should -Contain 'win:task:WezTermStats'
        # Shell integration is ours and has no prompt: removed even on a
        # fully-declined run, exactly at the recorded lines.
        (Get-Content -Path $ProfileFile -Raw) | Should -Not -Match 'starship init'
    }

    It 'removes exactly the owned entries, keeps strangers, and deletes the state' {
        if (-not $Script:TaskReady) {
            Set-ItResult -Skipped -Because 'this runner does not permit scheduled tasks'
            return
        }
        $Root = Join-Path $TestDrive 's3'
        $Fonts = Join-Path $Root 'fonts'
        New-Item -ItemType Directory -Force -Path $Fonts | Out-Null
        Set-Content -Path (Join-Path $Fonts 'Owned.ttf') -Value 'owned'
        Set-Content -Path (Join-Path $Fonts 'Stranger.ttf') -Value 'not ours'
        New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'WezCraftUninstTest (TrueType)' -Value (Join-Path $Fonts 'Owned.ttf') -PropertyType String -Force | Out-Null
        $ProfileFile = Join-Path $Root 'profile.ps1'
        Set-Content -Path $ProfileFile -Value @(
            'Set-StrictMode -Version Latest'
            $WezCraftStarshipProfileLine
            $WezCraftAtuinProfileLine
            '# starship init custom'
        )
        $Temp = Join-Path $Root 'temp'
        $Clone = Join-Path $Temp 'wezcraft-install'
        New-Item -ItemType Directory -Force -Path $Clone | Out-Null
        Set-Content -Path (Join-Path $Clone 'wezterm.lua') -Value 'clone'
        $StatsFile = Join-Path $Temp 'wezterm_stats.txt'
        Set-Content -Path $StatsFile -Value 'stats'
        Set-Content -Path (Join-Path $Temp 'user-file.txt') -Value 'not ours'
        $Target = Join-Path $Root '.config/wezterm'
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        $State = Join-Path $Root 'state'
        Add-InstallState -StateFile $State -Entry 'win:font:Owned.ttf'
        Add-InstallState -StateFile $State -Entry 'win:hkcu:WezCraftUninstTest (TrueType)'
        Add-InstallState -StateFile $State -Entry 'win:profile:starship-init'
        Add-InstallState -StateFile $State -Entry 'win:profile:atuin-init'
        Add-InstallState -StateFile $State -Entry "win:path:$Clone"
        Add-InstallState -StateFile $State -Entry "win:path:$StatsFile"
        Add-InstallState -StateFile $State -Entry 'win:task:WezCraftUninstTask'
        Mock Read-Host {
            $Text = "$Prompt"; if (-not $Text) { $Text = "$args" }
            [void]$global:WezCraftTestPrompts.Add($Text); 'y'
        }

        & $Uninstall -Target $Target -SavesDir (Join-Path $Root 'saves') -FontDir $Fonts -TempRoot $Temp -TaskName 'WezCraftUninstTask' -StateFile $State -ProfilePath $ProfileFile -LogFile (Join-Path $Root 'uninstall.log') | Out-Null

        $LASTEXITCODE | Should -Be 0
        # Fonts: owned file and its registry value gone, stranger untouched.
        Test-Path (Join-Path $Fonts 'Owned.ttf') | Should -BeFalse
        Test-Path (Join-Path $Fonts 'Stranger.ttf') | Should -BeTrue
        Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'WezCraftUninstTest (TrueType)' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        # Profile: only our exact lines removed; the look-alike survives.
        ((Get-Content -Path $ProfileFile) -join '|') | Should -BeExactly 'Set-StrictMode -Version Latest|# starship init custom'
        # Temp: owned paths gone, stranger file untouched.
        Test-Path $Clone | Should -BeFalse
        Test-Path $StatsFile | Should -BeFalse
        Test-Path (Join-Path $Temp 'user-file.txt') | Should -BeTrue
        # Task really unregistered.
        Get-ScheduledTask -TaskName 'WezCraftUninstTask' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        # State file deleted; no winget prompt appeared (nothing winget-owned).
        Test-Path $State | Should -BeFalse
        @($global:WezCraftTestPrompts | Where-Object { $_ -match 'Starship|Atuin' }).Count | Should -Be 0
    }

    It 'uninstalls via winget only the package the state says WezCraft installed' {
        $Root = Join-Path $TestDrive 's4'
        $FakeBin = Join-Path $Root 'fakebin'
        New-Item -ItemType Directory -Force -Path $FakeBin | Out-Null
        $Marker = Join-Path $Root 'winget-marker.txt'
        # Fake winget: records its arguments and succeeds. Real winget on the
        # runner is never reached because this directory is prepended to PATH.
        Set-Content -Path (Join-Path $FakeBin 'winget.bat') -Value "@echo off`r`necho %* >> `"$Marker`"`r`nexit /b 0" -Encoding Ascii
        $State = Join-Path $Root 'state'
        Add-InstallState -StateFile $State -Entry 'win:winget:Starship.Starship'
        Mock Read-Host {
            $Text = "$Prompt"; if (-not $Text) { $Text = "$args" }
            [void]$global:WezCraftTestPrompts.Add($Text); 'y'
        }

        $OldPath = $env:PATH
        $env:PATH = "$FakeBin;$OldPath"
        try {
            & $Uninstall -Target (Join-Path $Root '.config/wezterm') -SavesDir (Join-Path $Root 'saves') -FontDir (Join-Path $Root 'fonts') -TempRoot (Join-Path $Root 'temp') -StateFile $State -ProfilePath (Join-Path $Root 'profile.ps1') -LogFile (Join-Path $Root 'uninstall.log') | Out-Null
        } finally {
            $env:PATH = $OldPath
        }

        $LASTEXITCODE | Should -Be 0
        (Get-Content -Path $Marker -Raw) | Should -Match 'uninstall -e Starship.Starship'
        @($global:WezCraftTestPrompts | Where-Object { $_ -match 'Starship' }).Count | Should -Be 1
        Test-Path $State | Should -BeFalse
    }
}

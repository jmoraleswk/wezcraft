# Pester 5 tests for installer/scripts/wezcraft-win.ps1 (the shared Windows
# helper). These exercise REAL behavior with real injected temp paths: a real
# native command that really fails (cmd /c exit 3) and a real log file under
# Pester's $TestDrive. Nothing here touches a real user path, the registry, or
# the real PowerShell profile.

. "$PSScriptRoot/../scripts/wezcraft-win.ps1"

Describe 'WezCraft shared Windows helpers' {
    BeforeEach {
        Clear-InstallFailure
    }

    Context 'load-time contract' {
        It 'starts with no recorded failures' {
            @(Get-InstallFailure).Count | Should -Be 0
        }
    }

    Context 'Invoke-CheckedNative exit-code capture' {
        It 'reports a genuinely failing native command as a failure with its real exit code' {
            $Ok = Invoke-CheckedNative -Label 'failing' -Command { cmd /c exit 3 }

            $Ok | Should -BeFalse
            $Failures = @(Get-InstallFailure)
            $Failures.Count | Should -Be 1
            $Failures[0].Component | Should -Be 'failing'
            $Failures[0].ExitCode | Should -Be 3
        }

        It 'does not record a failure when the native command succeeds' {
            $Ok = Invoke-CheckedNative -Label 'succeeding' -Command { cmd /c exit 0 }

            $Ok | Should -BeTrue
            @(Get-InstallFailure).Count | Should -Be 0
        }

        It 'records a command that is not on PATH as a failure, not a success' {
            $Ok = Invoke-CheckedNative -Label 'missing' -Command { wezcraft-no-such-binary-xyz }

            $Ok | Should -BeFalse
            $Failures = @(Get-InstallFailure)
            $Failures.Count | Should -Be 1
            $Failures[0].Component | Should -Be 'missing'
            $Failures[0].ExitCode | Should -Be -1
            $Failures[0].Message | Should -Match 'PATH'
        }

        It 'appends captured native output to the log it is given' {
            $Log = Join-Path $TestDrive 'native.log'

            $null = Invoke-CheckedNative -Label 'ok' -Command { cmd /c "echo captured-line & exit 0" } -LogFile $Log

            Test-Path $Log | Should -BeTrue
            (Get-Content -Path $Log -Raw) | Should -Match 'captured-line'
        }
    }

    Context 'Write-InstallLog' {
        It 'writes a timestamped, levelled line to the exact path it is given' {
            $Log = Join-Path $TestDrive 'nested' 'install.log'

            Write-InstallLog -LogFile $Log -Message 'hello world'

            Test-Path $Log | Should -BeTrue
            $Line = Get-Content -Path $Log -Raw
            $Line | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] hello world'
        }

        It 'honors the requested level' {
            $Log = Join-Path $TestDrive 'level.log'

            Write-InstallLog -LogFile $Log -Message 'boom' -Level 'ERROR'

            (Get-Content -Path $Log -Raw) | Should -Match '\[ERROR\] boom'
        }

        It 'replaces an existing log on the first write instead of appending forever' {
            $Log = Join-Path $TestDrive 'rotate.log'
            Set-Content -Path $Log -Value 'STALE-FROM-A-PREVIOUS-RUN'

            Write-InstallLog -LogFile $Log -Message 'fresh line'

            $Content = Get-Content -Path $Log -Raw
            $Content | Should -Not -Match 'STALE-FROM-A-PREVIOUS-RUN'
            $Content | Should -Match 'fresh line'
        }
    }

    Context 'Start-InstallComponent' {
        It 'prints the [n/total] header for the component' {
            $Output = Start-InstallComponent -Index 2 -Total 6 -Name 'font' -InformationVariable Info
            $null = $Output

            ($Info | Out-String) | Should -Match '\[2/6\] font'
        }
    }

    Context 'Show-InstallSummary drives its status from real failure state' {
        It 'prints the green Done marker and returns 0 when nothing failed' {
            $Result = Show-InstallSummary -LogFile (Join-Path $TestDrive 'summary.log') -InformationVariable Info

            $Result | Should -Be 0
            ($Info | Out-String) | Should -Match '=== Done ==='
        }

        It 'prints each failure plus the log path and returns 1 when something failed' {
            $Log = Join-Path $TestDrive 'summary.log'
            Add-InstallFailure -Component 'atuin' -Message 'native command exited with code 3' -ExitCode 3

            $Result = Show-InstallSummary -LogFile $Log -InformationVariable Info

            $Result | Should -Be 1
            $Text = $Info | Out-String
            $Text | Should -Match 'atuin'
            $Text | Should -Match 'exit code 3'
            $Text | Should -Match ([regex]::Escape($Log))
        }
    }
}

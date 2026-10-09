# Pester 5 tests for installer/scripts/wezcraft-win.ps1 (the shared Windows
# helper). These exercise REAL behavior with real injected temp paths: a real
# native command that really fails (cmd /c exit 3) and a real log file under
# Pester's $TestDrive. Nothing here touches a real user path, the registry, or
# the real PowerShell profile.

# Dot-source the helper from BeforeAll, not from the file body: in Pester 5 the
# file body runs during Discovery, and functions defined there do not exist
# anymore when the Run phase executes the tests. The canonical v5 pattern.
BeforeAll {
    . "$PSScriptRoot/../scripts/wezcraft-win.ps1"
}

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

    Context 'Get-FileSha256' {
        It 'matches an externally computed SHA-256 constant' {
            $Path = Join-Path $TestDrive 'known.bin'
            [System.IO.File]::WriteAllText($Path, 'wezcraft-font-fixture', [System.Text.UTF8Encoding]::new($false))

            # Constant computed off-box (shasum -a 256) over the exact bytes above.
            Get-FileSha256 -Path $Path | Should -BeExactly '6ca24f25b5babbda5c15067e4f6e5a6b110cc1c5ca9f0d6e692a71395f7354b8'
        }
    }

    Context 'Install-FontArchive verifies, installs, and registers' {
        BeforeAll {
            $Archive = Join-Path $TestDrive 'font-archive.zip'
            $Fixture = Join-Path $TestDrive 'font-src'
            New-Item -ItemType Directory -Force -Path $Fixture | Out-Null
            Set-Content -Path (Join-Path $Fixture 'WezCraftTest-Regular.ttf') -Value 'fake ttf one'
            Set-Content -Path (Join-Path $Fixture 'WezCraftTest-Bold.ttf') -Value 'fake ttf two'
            Compress-Archive -Path (Join-Path $Fixture '*.ttf') -DestinationPath $Archive
        }

        AfterAll {
            $Key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            foreach ($Name in @('WezCraftTest-Regular (TrueType)', 'WezCraftTest-Bold (TrueType)')) {
                Remove-ItemProperty -Path $Key -Name $Name -ErrorAction SilentlyContinue
            }
        }

        It 'installs every TTF from a checksum-verified archive and registers each one in HKCU' {
            $Fonts = Join-Path $TestDrive 'fonts'
            $Extract = Join-Path $TestDrive 'extract-ok'

            $Ok = Install-FontArchive -ArchivePath $Archive -ExpectedSha256 (Get-FileSha256 -Path $Archive) -FontDir $Fonts -ExtractRoot $Extract

            $Ok | Should -BeTrue
            Test-Path (Join-Path $Fonts 'WezCraftTest-Regular.ttf') | Should -BeTrue
            Test-Path (Join-Path $Fonts 'WezCraftTest-Bold.ttf') | Should -BeTrue
            Test-Path (Join-Path $Extract 'wezcraft-font-extract') | Should -BeFalse

            $Key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            $Value = Get-ItemProperty -Path $Key -Name 'WezCraftTest-Regular (TrueType)'
            $Value.'WezCraftTest-Regular (TrueType)' | Should -Be (Join-Path $Fonts 'WezCraftTest-Regular.ttf')
        }

        It 'refuses a checksum mismatch, records it, and installs nothing' {
            $Fonts = Join-Path $TestDrive 'fonts-bad'
            $Extract = Join-Path $TestDrive 'extract-bad'

            $Ok = Install-FontArchive -ArchivePath $Archive -ExpectedSha256 ('0' * 64) -FontDir $Fonts -ExtractRoot $Extract

            $Ok | Should -BeFalse
            $Failures = @(Get-InstallFailure)
            $Failures.Count | Should -Be 1
            $Failures[0].ExitCode | Should -Be -3
            $Failures[0].Message | Should -Match 'SHA-256'
            Test-Path $Fonts | Should -BeFalse
            Test-Path (Join-Path $Extract 'wezcraft-font-extract') | Should -BeFalse
        }

        It 'fails when the verified archive contains no TTF files' {
            $NoTtf = Join-Path $TestDrive 'font-src-nottf'
            New-Item -ItemType Directory -Force -Path $NoTtf | Out-Null
            Set-Content -Path (Join-Path $NoTtf 'readme.txt') -Value 'no fonts here'
            $NoTtfZip = Join-Path $TestDrive 'font-archive-nottf.zip'
            Compress-Archive -Path (Join-Path $NoTtf '*') -DestinationPath $NoTtfZip

            $Ok = Install-FontArchive -ArchivePath $NoTtfZip -ExpectedSha256 (Get-FileSha256 -Path $NoTtfZip) -FontDir (Join-Path $TestDrive 'fonts-nottf') -ExtractRoot (Join-Path $TestDrive 'extract-nottf')

            $Ok | Should -BeFalse
            $Failures = @(Get-InstallFailure)
            $Failures.Count | Should -Be 1
            $Failures[0].ExitCode | Should -Be -5
        }
    }
}

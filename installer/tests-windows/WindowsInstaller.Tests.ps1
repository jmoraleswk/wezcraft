# Pester 5 tests for installer/scripts/windows.ps1.
#
# The installer is never EXECUTED here: running it would move real config,
# write the real PowerShell profile, and register a real scheduled task. These
# tests parse the script's real AST so they validate the actual parameter
# defaults and the actual body, not a re-statement of assumptions. No real
# profile, registry, or font directory is ever touched.

# These tests resolve real Windows paths ($env:USERPROFILE / $env:LOCALAPPDATA /
# $env:TEMP). Off Windows those variables are $null and Join-Path throws an
# opaque binding error. Detect the host in the Discovery phase -- which is when
# -Skip is evaluated -- and skip every Describe with a clear message instead of
# failing on a platform these tests do not target.
BeforeDiscovery {
    $OnWindows = ($env:OS -eq 'Windows_NT')
    if (-not $OnWindows) {
        Write-Host "Skipping WindowsInstaller.Tests.ps1: it requires Windows (env:OS / USERPROFILE / LOCALAPPDATA are not set here). CI runs it on windows-latest."
    }
}

BeforeAll {
    # Recompute rather than reuse the Discovery variable (which is not visible in
    # run-time blocks): the Describe blocks are already skipped off Windows, but
    # keep the setup harmless if that wiring ever changes.
    if ($env:OS -ne 'Windows_NT') {
        return
    }

    $ScriptPath = Join-Path $PSScriptRoot '../scripts/windows.ps1'

    $Tokens = $null
    $ParseErrors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$Tokens, [ref]$ParseErrors)

    $ParamBlock = $Ast.ParamBlock

    # Resolve each parameter default by evaluating its real expression, so the
    # assertion compares against a real computed path (e.g. Join-Path), not a
    # copy of the source text.
    $Defaults = @{}
    foreach ($Parameter in $ParamBlock.Parameters) {
        if ($Parameter.DefaultValue) {
            $Name = $Parameter.Name.VariablePath.UserPath
            $Defaults[$Name] = & ([ScriptBlock]::Create($Parameter.DefaultValue.Extent.Text))
        }
    }

    $Text = Get-Content -Path $ScriptPath -Raw
    $Body = $Text.Substring($ParamBlock.Extent.EndOffset)

    # Parse the shared helper here as well: WezCraftWin.Tests.ps1 dot-sources it
    # at discovery time, so a syntax error there kills that entire container as
    # an opaque failure. Parsing it here surfaces the same breakage as a named,
    # readable assertion.
    $HelperPath = Join-Path $PSScriptRoot '../scripts/wezcraft-win.ps1'
    $HelperTokens = $null
    $HelperParseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $HelperPath, [ref]$HelperTokens, [ref]$HelperParseErrors)

    # Every command invocation in the file, nested script blocks included, so
    # routing can be asserted structurally instead of by substring.
    $AllCommands = @($Ast.FindAll({
        param($Node)
        $Node -is [System.Management.Automation.Language.CommandAst]
    }, $true))
}

Describe 'windows.ps1 parameter defaults' -Skip:(-not $OnWindows) {
    It 'parses without syntax errors' {
        $ParseErrors | Should -BeNullOrEmpty
    }

    It 'resolves $Target to the previously hardcoded config path' {
        $Defaults['Target'] | Should -Be (Join-Path $env:USERPROFILE '.config\wezterm')
    }

    It 'resolves $FontDir to the previously hardcoded font directory' {
        $Defaults['FontDir'] | Should -Be (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts')
    }

    It 'resolves $TempRoot to $env:TEMP' {
        $Defaults['TempRoot'] | Should -Be $env:TEMP
    }

    It 'resolves $TaskName to the previous scheduled-task name' {
        $Defaults['TaskName'] | Should -Be 'WezTermStats'
    }

    It 'resolves $LogFile to wezcraft-install.log in TEMP' {
        $Defaults['LogFile'] | Should -Be (Join-Path $env:TEMP 'wezcraft-install.log')
    }

    It 'pins the font archive URL to the same release pkg.sh verifies' {
        $Defaults['FontUrl'] | Should -Match 'releases/download/v3\.5\.1/FiraCode\.zip'
        $Defaults['FontUrl'] | Should -Not -Match 'latest/download'
    }

    It 'pins the font archive SHA-256 from the same release' {
        $Defaults['FontSha256'] | Should -MatchExactly '^[0-9a-f]{64}$'
    }

    It 'gives $ProfilePath no fragile in-param-block default' {
        $Defaults.ContainsKey('ProfilePath') | Should -BeFalse
    }
}

Describe 'wezcraft-win.ps1 syntax' -Skip:(-not $OnWindows) {
    It 'parses without syntax errors' {
        $HelperParseErrors | Should -BeNullOrEmpty
    }
}

Describe 'windows.ps1 uses its injectable seams' -Skip:(-not $OnWindows) {
    It 'reads the config target from $Target, not a hardcoded path' {
        $Body | Should -Match '\$Target'
        $Body | Should -Not -Match 'USERPROFILE\\\.config\\wezterm'
    }

    It 'reads the font directory from $FontDir, not a hardcoded path' {
        $Body | Should -Match '\$FontDir'
        $Body | Should -Not -Match 'Microsoft\\Windows\\Fonts'
    }

    It 'derives temp paths from $TempRoot, not $env:TEMP' {
        $Body | Should -Match '\$TempRoot'
        $Body | Should -Not -Match '\$env:TEMP'
    }

    It 'resolves $ProfilePath in the body and writes to it, never to a bare $PROFILE' {
        # MatchExactly, not -Match -CaseSensitive: the classic Should -Match has
        # no CaseSensitive switch in Pester 5; MatchExactly asserts with -cmatch.
        $Body | Should -MatchExactly '\$ProfilePath = \$PROFILE'
        $Body | Should -MatchExactly 'Test-Path \$ProfilePath'
        $Body | Should -MatchExactly 'Out-File -FilePath \$ProfilePath'
    }
}

Describe 'windows.ps1 routes native commands through the helper' -Skip:(-not $OnWindows) {
    It 'places every git/tar/winget invocation inside an Invoke-CheckedNative call' {
        # Structural check, not a substring check: a native call sitting bare in
        # the body -- the exact way a helper could be bypassed -- would have a
        # nearest enclosing command that is not Invoke-CheckedNative.
        $NativeNames = @('git', 'winget')
        $NativeCalls = @($AllCommands | Where-Object { $NativeNames -contains $_.GetCommandName() })

        $NativeCalls.Count | Should -BeGreaterThan 0
        foreach ($Call in $NativeCalls) {
            $Enclosing = $null
            $Parent = $Call.Parent
            while ($Parent) {
                if ($Parent -is [System.Management.Automation.Language.CommandAst]) {
                    $Enclosing = $Parent.GetCommandName()
                    break
                }
                $Parent = $Parent.Parent
            }
            $Enclosing | Should -Be 'Invoke-CheckedNative'
        }

        # Honest limit: this proves static routing from the parsed source only.
        # That a routed native command really runs and its real $LASTEXITCODE is
        # read needs a Windows host; the CI job on windows-latest exercises that,
        # this parse cannot.
    }
}

Describe 'windows.ps1 exits with the summary result' -Skip:(-not $OnWindows) {
    It 'assigns $ExitCode from Show-InstallSummary and exits with it' {
        $Body | Should -Match '\$ExitCode\s*=\s*Show-InstallSummary'

        # Deleting the trailing `exit $ExitCode` makes the last statement the
        # gated success block instead, so this assertion fails with it.
        $LastStatement = $Ast.EndBlock.Statements | Select-Object -Last 1
        $LastStatement.Extent.Text.Trim() | Should -Be 'exit $ExitCode'
    }
}

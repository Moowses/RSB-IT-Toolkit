$global:RSBITToolkitTestRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $global:RSBITToolkitTestRoot 'RSBITToolkit.psd1') -Force

Describe 'RSB IT Toolkit regression contract' {
    BeforeAll {
        if ([string]::IsNullOrWhiteSpace($global:RSBITToolkitTestRoot)) { $global:RSBITToolkitTestRoot = (Get-Location).Path }
        $interactiveSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Get-RSBInteractiveUser.ps1') -Raw
        $interactiveExecutable = $interactiveSource -replace '(?m)^\s*#.*$',''
        $standardSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Ensure-RSBStandardUser.ps1') -Raw
        $adminSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Ensure-RSBITAdmin.ps1') -Raw
        $baselineSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Invoke-RSBBranchSecurityBaseline.ps1') -Raw
        $controlSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Set-RSBControlPanelPolicy.ps1') -Raw
        $stateSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/New-RSBStateBackup.ps1') -Raw
        $systemSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Get-RSBSystemInfo.ps1') -Raw
        $startSource = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'scripts/start.ps1') -Raw
    }

    It 'supports the Windows 10 build fixture' { ($systemSource -match 'if \(\$build -ge 22000\)') | Should -BeTrue }
    It 'supports the Windows 11 build fixture despite legacy product strings' { ($systemSource -match 'RegistryProductName') | Should -BeTrue; ($systemSource -match 'DisplayName') | Should -BeTrue }
    It 'never uses CIM or WMI to find the interactive user' { ($interactiveExecutable -notmatch 'Get-CimInstance|Get-WmiObject|Win32_ComputerSystem') | Should -BeTrue }
    It 'uses Explorer first, then query user as a non-CIM fallback' { ($interactiveSource -match 'Get-Process -Name explorer') | Should -BeTrue; ($interactiveSource -match 'quser') | Should -BeTrue }
    It 'rejects multiple interactive sessions' { ($interactiveSource -match 'Count -ne 1') | Should -BeTrue }
    It 'rejects a missing Explorer/session identity rather than guessing from elevated USERNAME' { ($interactiveSource -match 'Expected exactly one safe active') | Should -BeTrue; ($interactiveSource -notmatch '\$env:USERNAME') | Should -BeTrue }
    It 'blocks domain, Entra, and Microsoft Account identities in v1' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Get-RSBLocalIdentity.ps1') -Raw) -match 'Unsupported interactive identity') | Should -BeTrue }
    It 'uses a LocalUser object to survive computer-name equals username' { ($standardSource -match 'Add-LocalGroupMember -Group \$users -Member \$user') | Should -BeTrue }
    It 'adds and verifies Users membership before Administrators removal' {
        ($baselineSource.IndexOf('Ensure-RSBStandardUser') -lt $baselineSource.IndexOf('Remove-LocalGroupMember')) | Should -BeTrue
        ($standardSource -match 'not touched') | Should -BeTrue
    }
    It 'detects an unavailable LocalAccounts module with a native-PowerShell remediation' {
        ($standardSource -match 'LocalAccounts module unavailable') | Should -BeTrue
        ($startSource -match 'Start-RSBNativePowerShell') | Should -BeTrue
    }
    It 'redirects a simulated 32-bit launcher on a 64-bit OS to Sysnative' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Start-RSBNativePowerShell.ps1') -Raw) -match 'Sysnative') | Should -BeTrue }
    It 'waits for elevated/native child launch before a bootstrapper can clean temporary files' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Start-RSBNativePowerShell.ps1') -Raw) -match 'Start-Process .* -Wait') | Should -BeTrue; ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'scripts/start.ps1') -Raw) -match 'Start-Process powershell\.exe -Verb RunAs -Wait') | Should -BeTrue }
    It 'does not call ADSI SetPassword until after account commit' {
        ($adminSource.IndexOf('$account.SetInfo()') -lt $adminSource.IndexOf('$account.SetPassword($plain)')) | Should -BeTrue
    }
    It 'is idempotent for an existing RSB IT Admin and employee already standard' { ($adminSource -match 'Get-LocalUser -Name \$name') | Should -BeTrue; ($standardSource -match 'if \(-not \$present\)') | Should -BeTrue }
    It 'requires an enabled verified recovery administrator before employee admin removal' {
        ($baselineSource.IndexOf('Ensure-RSBITAdmin') -lt $baselineSource.IndexOf('Remove-LocalGroupMember')) | Should -BeTrue
        ($adminSource -match 'could not be verified') | Should -BeTrue
    }
    It 'catches time-policy apply failure' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Set-RSBTimeRights.ps1') -Raw) -match 'secedit failed applying') | Should -BeTrue }
    It 'attempts rollback on final verification failure' { ($baselineSource -match 'Critical final verification failed') | Should -BeTrue; ($baselineSource -match 'Restore-RSBStateBackup') | Should -BeTrue }
    It 'reports rollback failure separately' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'functions/public/Restore-RSBStateBackup.ps1') -Raw) -match 'RollbackFailed') | Should -BeTrue }
    It 'targets NoControlPanel at the employee SID hive and not elevated HKCU' { ($controlSource -match 'HKEY_USERS') | Should -BeTrue; ($controlSource -notmatch 'HKCU:') | Should -BeTrue }
    It 'requires matching password prompts in the GUI' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'scripts/main.ps1') -Raw) -match 'Passwords do not match') | Should -BeTrue }
    It 'loads WPF markup explicitly as UTF-8 and suppresses non-actionable module verb warnings' { $main = Get-Content (Join-Path $global:RSBITToolkitTestRoot 'scripts/main.ps1') -Raw; ($main -match 'Get-Content .* -Encoding UTF8') | Should -BeTrue; ($main -match 'Import-Module .* -DisableNameChecking') | Should -BeTrue }
    It 'does not serialize passwords to state' { ($stateSource -notmatch 'Password|SecureString|ConvertFrom-RSBSecureString') | Should -BeTrue }
    It 'uses a normal PowerShell release model rather than embedded BAT markers' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'bootstrap.ps1') -Raw) -notmatch '::.*PAYLOAD|Invoke-Expression.*marker') | Should -BeTrue }
    It 'explains safely when an approved release asset is not available' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'bootstrap.ps1') -Raw) -match 'No approved RSB IT Toolkit') | Should -BeTrue }
    It 'launches the verified extracted entry point with process-scoped execution-policy bypass' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'bootstrap.ps1') -Raw) -match '-ExecutionPolicy Bypass -File \$entry.FullName') | Should -BeTrue }
    It 'resolves only published prereleases for the engineering-preview channel' { ((Get-Content (Join-Path $global:RSBITToolkitTestRoot 'bootstrap.ps1') -Raw) -match 'prerelease -and -not \$_.draft') | Should -BeTrue }
}

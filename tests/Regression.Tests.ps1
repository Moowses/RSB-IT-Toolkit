$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'RSBITToolkit.psd1') -Force

Describe 'RSB IT Toolkit regression contract' {
    BeforeAll {
        $interactiveSource = Get-Content (Join-Path $root 'functions/public/Get-RSBInteractiveUser.ps1') -Raw
        $interactiveExecutable = $interactiveSource -replace '(?m)^\s*#.*$',''
        $standardSource = Get-Content (Join-Path $root 'functions/public/Ensure-RSBStandardUser.ps1') -Raw
        $adminSource = Get-Content (Join-Path $root 'functions/public/Ensure-RSBITAdmin.ps1') -Raw
        $baselineSource = Get-Content (Join-Path $root 'functions/public/Invoke-RSBBranchSecurityBaseline.ps1') -Raw
        $controlSource = Get-Content (Join-Path $root 'functions/public/Set-RSBControlPanelPolicy.ps1') -Raw
        $stateSource = Get-Content (Join-Path $root 'functions/public/New-RSBStateBackup.ps1') -Raw
        $systemSource = Get-Content (Join-Path $root 'functions/public/Get-RSBSystemInfo.ps1') -Raw
        $startSource = Get-Content (Join-Path $root 'scripts/start.ps1') -Raw
    }

    It 'supports the Windows 10 build fixture' { ($systemSource -match 'if \(\$build -ge 22000\)') | Should Be $true }
    It 'supports the Windows 11 build fixture despite legacy product strings' { ($systemSource -match 'RegistryProductName') | Should Be $true; ($systemSource -match 'DisplayName') | Should Be $true }
    It 'never uses CIM or WMI to find the interactive user' { ($interactiveExecutable -notmatch 'Get-CimInstance|Get-WmiObject|Win32_ComputerSystem') | Should Be $true }
    It 'uses Explorer first, then query user as a non-CIM fallback' { ($interactiveSource -match 'Get-Process -Name explorer') | Should Be $true; ($interactiveSource -match 'quser') | Should Be $true }
    It 'rejects multiple interactive sessions' { ($interactiveSource -match 'Count -ne 1') | Should Be $true }
    It 'rejects a missing Explorer/session identity rather than guessing from elevated USERNAME' { ($interactiveSource -match 'Expected exactly one safe active') | Should Be $true; ($interactiveSource -notmatch '\$env:USERNAME') | Should Be $true }
    It 'blocks domain, Entra, and Microsoft Account identities in v1' { ((Get-Content (Join-Path $root 'functions/public/Get-RSBLocalIdentity.ps1') -Raw) -match 'Unsupported interactive identity') | Should Be $true }
    It 'uses a LocalUser object to survive computer-name equals username' { ($standardSource -match 'Add-LocalGroupMember -Group \$users -Member \$user') | Should Be $true }
    It 'adds and verifies Users membership before Administrators removal' {
        ($baselineSource.IndexOf('Ensure-RSBStandardUser') -lt $baselineSource.IndexOf('Remove-LocalGroupMember')) | Should Be $true
        ($standardSource -match 'not touched') | Should Be $true
    }
    It 'detects an unavailable LocalAccounts module with a native-PowerShell remediation' {
        ($standardSource -match 'LocalAccounts module unavailable') | Should Be $true
        ($startSource -match 'Start-RSBNativePowerShell') | Should Be $true
    }
    It 'redirects a simulated 32-bit launcher on a 64-bit OS to Sysnative' { ((Get-Content (Join-Path $root 'functions/public/Start-RSBNativePowerShell.ps1') -Raw) -match 'Sysnative') | Should Be $true }
    It 'does not call ADSI SetPassword until after account commit' {
        ($adminSource.IndexOf('$account.SetInfo()') -lt $adminSource.IndexOf('$account.SetPassword($plain)')) | Should Be $true
    }
    It 'is idempotent for an existing RSB IT Admin and employee already standard' { ($adminSource -match 'Get-LocalUser -Name \$name') | Should Be $true; ($standardSource -match 'if \(-not \$present\)') | Should Be $true }
    It 'requires an enabled verified recovery administrator before employee admin removal' {
        ($baselineSource.IndexOf('Ensure-RSBITAdmin') -lt $baselineSource.IndexOf('Remove-LocalGroupMember')) | Should Be $true
        ($adminSource -match 'could not be verified') | Should Be $true
    }
    It 'catches time-policy apply failure' { ((Get-Content (Join-Path $root 'functions/public/Set-RSBTimeRights.ps1') -Raw) -match 'secedit failed applying') | Should Be $true }
    It 'attempts rollback on final verification failure' { ($baselineSource -match 'Critical final verification failed') | Should Be $true; ($baselineSource -match 'Restore-RSBStateBackup') | Should Be $true }
    It 'reports rollback failure separately' { ((Get-Content (Join-Path $root 'functions/public/Restore-RSBStateBackup.ps1') -Raw) -match 'RollbackFailed') | Should Be $true }
    It 'targets NoControlPanel at the employee SID hive and not elevated HKCU' { ($controlSource -match 'HKEY_USERS') | Should Be $true; ($controlSource -notmatch 'HKCU:') | Should Be $true }
    It 'requires matching password prompts in the GUI' { ((Get-Content (Join-Path $root 'scripts/main.ps1') -Raw) -match 'Passwords do not match') | Should Be $true }
    It 'does not serialize passwords to state' { ($stateSource -notmatch 'Password|SecureString|ConvertFrom-RSBSecureString') | Should Be $true }
    It 'uses a normal PowerShell release model rather than embedded BAT markers' { ((Get-Content (Join-Path $root 'bootstrap.ps1') -Raw) -notmatch '::.*PAYLOAD|Invoke-Expression.*marker') | Should Be $true }
}

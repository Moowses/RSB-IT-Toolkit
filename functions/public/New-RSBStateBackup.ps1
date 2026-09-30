function New-RSBStateBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Employee, [Parameter(Mandatory)]$AccountState)

    $paths = Initialize-RSBPaths
    $transactionId = [guid]::NewGuid().Guid
    $policyPath = Join-Path $paths.State ("{0}-security-policy.inf" -f $transactionId)
    & secedit.exe /export /cfg $policyPath /quiet | Out-Null
    if (-not (Test-Path -LiteralPath $policyPath)) { throw 'Unable to export local security policy; refusing to start transaction.' }

    $controlPath = "Registry::HKEY_USERS\\$($Employee.Sid)\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer"
    $existing = Get-ItemProperty -Path $controlPath -Name NoControlPanel -ErrorAction SilentlyContinue
    $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $uac = Get-ItemProperty -Path $uacPath -ErrorAction Stop
    $state = [pscustomobject]@{
        TransactionId = $transactionId; Status = 'BackedUp'; CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Employee = $AccountState; PolicyBackupPath = $policyPath
        ControlPanelOriginal = [pscustomobject]@{ Path = $controlPath; Exists = ($null -ne $existing); Value = if ($existing) { $existing.NoControlPanel } else { $null } }
        UacOriginal = [pscustomobject]@{ ConsentPromptBehaviorUser = $uac.ConsentPromptBehaviorUser; PromptOnSecureDesktop = $uac.PromptOnSecureDesktop }
        Steps = @(); Rollback = $null
    }
    $statePath = Join-Path $paths.State ("{0}.json" -f $transactionId)
    Save-RSBState -State $state -Path $statePath
    Write-RSBLog -TransactionId $transactionId -Message "State backup created: $statePath"
    return [pscustomobject]@{ State = $state; Path = $statePath }
}

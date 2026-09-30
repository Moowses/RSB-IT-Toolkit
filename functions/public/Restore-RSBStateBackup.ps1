function Restore-RSBStateBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)

    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $state.Status = 'RollingBack'; Save-RSBState -State $state -Path $StatePath
    $errors = @()
    try {
        if (Test-Path -LiteralPath $state.PolicyBackupPath) {
            & secedit.exe /configure /db (Join-Path $env:TEMP 'RSB-IT-restore.sdb') /cfg $state.PolicyBackupPath /areas SECURITYPOLICY USER_RIGHTS /quiet | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "secedit restore failed (exit $LASTEXITCODE)." }
        } else { throw 'Saved policy backup does not exist.' }
    } catch { $errors += $_.Exception.Message }
    try { Undo-RSBControlPanelPolicy -ControlPanelOriginal $state.ControlPanelOriginal -Confirm:$false } catch { $errors += $_.Exception.Message }
    try {
        $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        New-ItemProperty -Path $uacPath -Name ConsentPromptBehaviorUser -PropertyType DWord -Value $state.UacOriginal.ConsentPromptBehaviorUser -Force | Out-Null
        New-ItemProperty -Path $uacPath -Name PromptOnSecureDesktop -PropertyType DWord -Value $state.UacOriginal.PromptOnSecureDesktop -Force | Out-Null
    } catch { $errors += $_.Exception.Message }
    try {
        $employee = Get-LocalUser -SID $state.Employee.Sid -ErrorAction Stop
        $users = Resolve-RSBLocalGroup -Sid 'S-1-5-32-545'; $admins = Resolve-RSBLocalGroup -Sid 'S-1-5-32-544'
        $inUsers = Get-LocalGroupMember -Group $users | Where-Object { $_.SID -and $_.SID.Value -eq $state.Employee.Sid }
        $inAdmins = Get-LocalGroupMember -Group $admins | Where-Object { $_.SID -and $_.SID.Value -eq $state.Employee.Sid }
        if ($state.Employee.InUsers -and -not $inUsers) { Add-LocalGroupMember -Group $users -Member $employee }
        if (-not $state.Employee.InUsers -and $inUsers) { Remove-LocalGroupMember -Group $users -Member $employee }
        if ($state.Employee.InAdministrators -and -not $inAdmins) { Add-LocalGroupMember -Group $admins -Member $employee }
        if (-not $state.Employee.InAdministrators -and $inAdmins) { Remove-LocalGroupMember -Group $admins -Member $employee }
    } catch { $errors += $_.Exception.Message }
    $state.Rollback = [pscustomobject]@{ CompletedUtc = [DateTime]::UtcNow.ToString('o'); Errors = @($errors) }
    $state.Status = if ($errors.Count) { 'RollbackFailed' } else { 'RolledBack' }
    Save-RSBState -State $state -Path $StatePath
    Write-RSBLog -TransactionId $state.TransactionId -Level $(if ($errors.Count) { 'FAILED' } else { 'ROLLBACK' }) -Message "Rollback status: $($state.Status)"
    return $state
}

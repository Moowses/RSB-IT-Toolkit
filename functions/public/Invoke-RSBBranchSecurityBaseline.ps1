function Invoke-RSBBranchSecurityBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Security.SecureString]$Password, [switch]$ApplyControlPanelRestriction)

    if (-not (Test-RSBElevation)) { throw 'Administrator elevation is required.' }
    $info = Get-RSBSystemInfo
    $interactive = Get-RSBInteractiveUser
    $employee = Get-RSBLocalIdentity -InteractiveUser $interactive
    $initial = Get-RSBAccountState -Identity $employee
    if (-not $initial.Enabled) { throw 'Employee account is disabled; baseline is not safe to proceed.' }
    $backup = New-RSBStateBackup -Employee $employee -AccountState $initial
    $state = $backup.State; $state.Status = 'Applying'; Save-RSBState -State $state -Path $backup.Path
    try {
        $admin = Ensure-RSBITAdmin -Password $Password; Set-RSBTransactionStep $state 'RecoveryAdminVerified' 'Completed' | Out-Null; Save-RSBState $state $backup.Path
        $employeeState = Ensure-RSBStandardUser -Employee $employee; Set-RSBTransactionStep $state 'EmployeeUsersVerified' 'Completed' | Out-Null; Save-RSBState $state $backup.Path
        Set-RSBUacPolicy -Confirm:$false; Set-RSBTransactionStep $state 'UacPolicy' 'Completed' | Out-Null
        Set-RSBTimeRights -PolicyBackupPath $state.PolicyBackupPath -Confirm:$false | Out-Null
        if (-not (Test-RSBTimeRights)) { throw 'Time user-rights verification failed.' }
        Set-RSBTransactionStep $state 'TimeRights' 'Completed' | Out-Null
        if ($ApplyControlPanelRestriction) { Set-RSBControlPanelPolicy -Employee $employee -Confirm:$false; Set-RSBTransactionStep $state 'ControlPanelPolicy' 'Completed' | Out-Null }
        Save-RSBState $state $backup.Path
        $admins = Resolve-RSBLocalGroup -Sid 'S-1-5-32-544'
        $isEmployeeAdmin = Get-LocalGroupMember -Group $admins | Where-Object { $_.SID -and $_.SID.Value -eq $employee.Sid }
        if ($isEmployeeAdmin) { Remove-LocalGroupMember -Group $admins -Member $employee.Principal -ErrorAction Stop }
        Set-RSBTransactionStep $state 'EmployeeAdminRemoved' 'Completed' | Out-Null
        $final = Get-RSBAccountState -Identity $employee
        if (-not $final.Enabled -or -not $final.InUsers -or $final.InAdministrators -or -not $admin.InAdministrators) { throw 'Critical final verification failed.' }
        $state.Status = 'Succeeded'; Save-RSBState $state $backup.Path
        Write-RSBLog -TransactionId $state.TransactionId -Level SUCCESS -Message "Baseline succeeded on $($info.ComputerName)."
        return [pscustomobject]@{ Status='SUCCESS'; StatePath=$backup.Path; TransactionId=$state.TransactionId; Employee=$final }
    } catch {
        $failure = $_.Exception.Message; Write-RSBLog -TransactionId $state.TransactionId -Level FAILED -Message "Baseline failed: $failure"
        $rollback = Restore-RSBStateBackup -StatePath $backup.Path
        return [pscustomobject]@{ Status='FAILED'; Error=$failure; StatePath=$backup.Path; TransactionId=$state.TransactionId; RollbackStatus=$rollback.Status }
    }
}

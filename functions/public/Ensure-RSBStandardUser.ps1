function Ensure-RSBStandardUser {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Employee)

    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) { throw 'LocalAccounts module unavailable; cannot safely alter local memberships.' }
    $user = Get-LocalUser -SID $Employee.Sid -ErrorAction Stop
    if (-not $user.Enabled) { Enable-LocalUser -Name $user.Name; $user = Get-LocalUser -SID $Employee.Sid }
    $users = Resolve-RSBLocalGroup -Sid 'S-1-5-32-545'
    $present = Get-LocalGroupMember -Group $users | Where-Object { $_.SID -and $_.SID.Value -eq $Employee.Sid }
    # Pass a LocalUser object rather than an ambiguous account-name string (PC name may equal user name).
    if (-not $present) { Add-LocalGroupMember -Group $users -Member $user -ErrorAction Stop }
    $state = Get-RSBAccountState -Identity ([pscustomobject]@{ Name=$user.Name; Sid=$user.SID.Value; Enabled=$user.Enabled; Principal=$user; ProfilePath=$Employee.ProfilePath })
    if (-not $state.Enabled -or -not $state.InUsers) { throw 'Employee standard-user membership verification failed; Administrators membership was not touched.' }
    return $state
}

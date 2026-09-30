function Get-RSBAccountState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Identity)

    $users = Resolve-RSBLocalGroup -Sid 'S-1-5-32-545'
    $admins = Resolve-RSBLocalGroup -Sid 'S-1-5-32-544'
    $memberOf = {
        param($Group, $Sid)
        return [bool](Get-LocalGroupMember -Group $Group -ErrorAction Stop | Where-Object { $_.SID -and $_.SID.Value -eq $Sid })
    }
    [pscustomobject]@{
        Name = $Identity.Name; Sid = $Identity.Sid; Enabled = [bool]$Identity.Enabled; ProfilePath = $Identity.ProfilePath
        InUsers = & $memberOf $users $Identity.Sid
        InAdministrators = & $memberOf $admins $Identity.Sid
    }
}

function Resolve-RSBLocalGroup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Sid)

    if (Get-Command Get-LocalGroup -ErrorAction SilentlyContinue) {
        $group = Get-LocalGroup | Where-Object { $_.SID.Value -eq $Sid }
        if ($group) { return $group }
    }
    throw "Cannot resolve local group with SID $Sid. Microsoft.PowerShell.LocalAccounts is required for this operation."
}

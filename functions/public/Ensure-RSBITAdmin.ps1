function Ensure-RSBITAdmin {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Security.SecureString]$Password)

    $name = 'RSB IT Admin'
    $description = 'Rose Bakeshop IT Administrative Account'
    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        $account = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
        if (-not $account) { $account = New-LocalUser -Name $name -Description $description -Password $Password -FullName $name -ErrorAction Stop }
        else { Set-LocalUser -Name $name -Password $Password -Description $description; Enable-LocalUser -Name $name; $account = Get-LocalUser -Name $name }
        if (-not $account.Enabled) { Enable-LocalUser -Name $name; $account = Get-LocalUser -Name $name }
        $admins = Resolve-RSBLocalGroup -Sid 'S-1-5-32-544'
        $isAdmin = Get-LocalGroupMember -Group $admins | Where-Object { $_.SID -and $_.SID.Value -eq $account.SID.Value }
        if (-not $isAdmin) { Add-LocalGroupMember -Group $admins -Member $account -ErrorAction Stop }
        $state = Get-RSBAccountState -Identity ([pscustomobject]@{ Name = $account.Name; Sid = $account.SID.Value; Enabled = $account.Enabled; Principal = $account; ProfilePath = $null })
        if (-not $state.Enabled -or -not $state.InAdministrators) { throw 'RSB IT Admin could not be verified as an enabled local administrator.' }
        return $state
    }

    # Fallback commits the account before SetPassword; it never calls SetPassword on an uncommitted ADSI object.
    $computer = [ADSI]("WinNT://{0},computer" -f $env:COMPUTERNAME)
    $account = $computer.Children | Where-Object { $_.SchemaClassName -eq 'User' -and $_.Name -eq $name }
    $plain = ConvertFrom-RSBSecureString -SecureString $Password
    try {
        if (-not $account) { $account = $computer.Create('User', $name); $account.SetInfo() }
        $account.SetPassword($plain); $account.Put('Description', $description); $account.SetInfo()
    } finally { $plain = $null }
    throw 'LocalAccounts fallback created/updated the account but membership verification requires the native LocalAccounts module. Relaunch in 64-bit PowerShell.'
}

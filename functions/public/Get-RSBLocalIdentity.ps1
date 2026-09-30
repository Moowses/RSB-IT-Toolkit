function Get-RSBLocalIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$InteractiveUser)

    if ($InteractiveUser.QualifiedName -match 'AzureAD|MicrosoftAccount|@' -or $InteractiveUser.QualifiedName -match '\\' -and $InteractiveUser.QualifiedName -notmatch "^$([regex]::Escape($env:COMPUTERNAME))\\") {
        throw "Unsupported interactive identity '$($InteractiveUser.QualifiedName)'. v1 supports a local Windows account only."
    }
    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) { throw 'Microsoft.PowerShell.LocalAccounts is unavailable. Relaunch native 64-bit Windows PowerShell.' }
    $local = Get-LocalUser -Name $InteractiveUser.Name -ErrorAction Stop
    $profile = Get-ItemProperty -Path ("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\\{0}" -f $local.SID.Value) -Name ProfileImagePath -ErrorAction SilentlyContinue
    [pscustomobject]@{ Name = $local.Name; Sid = $local.SID.Value; Enabled = [bool]$local.Enabled; Principal = $local; ProfilePath = if ($profile) { [Environment]::ExpandEnvironmentVariables($profile.ProfileImagePath) } else { $null } }
}

function Set-RSBControlPanelPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)]$Employee)

    $path = "Registry::HKEY_USERS\\$($Employee.Sid)\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer"
    if (-not (Test-Path -LiteralPath $path) -and $Employee.ProfilePath) {
        $ntUser = Join-Path $Employee.ProfilePath 'NTUSER.DAT'
        if (Test-Path -LiteralPath $ntUser) {
            $loadedHive = "RSB_$($Employee.Sid -replace '-','_')"
            & reg.exe load "HKU\\$loadedHive" $ntUser | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Unable to load employee hive for $($Employee.Sid)." }
            try { $path = "Registry::HKEY_USERS\\$loadedHive\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" }
            finally { $unloadHive = $loadedHive }
        }
    }
    try {
        if ($PSCmdlet.ShouldProcess($path, 'Set employee-only NoControlPanel policy')) {
            New-Item -Path $path -Force | Out-Null
            New-ItemProperty -Path $path -Name NoControlPanel -PropertyType DWord -Value 1 -Force | Out-Null
        }
    } finally {
        if ($unloadHive) { & reg.exe unload "HKU\\$unloadHive" | Out-Null }
    }
}

function Start-RSBNativePowerShell {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath, [string[]]$ArgumentList = @())

    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $native = Join-Path $env:WINDIR 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $native)) { throw 'Native 64-bit Windows PowerShell was not found.' }
        # Wait so a bootstrapper cannot delete its verified temporary payload before this native child reads it.
        Start-Process -FilePath $native -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',("`"{0}`"" -f $ScriptPath)) + $ArgumentList
        return $true
    }
    return $false
}

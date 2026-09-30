function Start-RSBNativePowerShell {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath, [string[]]$ArgumentList = @())

    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $native = Join-Path $env:WINDIR 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $native)) { throw 'Native 64-bit Windows PowerShell was not found.' }
        Start-Process -FilePath $native -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',("`"{0}`"" -f $ScriptPath)) + $ArgumentList
        return $true
    }
    return $false
}

[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'RSBITToolkit.psd1') -Force
if (Start-RSBNativePowerShell -ScriptPath $PSCommandPath) { return }
if (-not (Test-RSBElevation)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',("`"{0}`"" -f $PSCommandPath))
    return
}
& (Join-Path $PSScriptRoot 'main.ps1')

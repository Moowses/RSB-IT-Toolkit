[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'RSBITToolkit.psd1') -Force -DisableNameChecking
if (Start-RSBNativePowerShell -ScriptPath $PSCommandPath) { return }
if (-not (Test-RSBElevation)) {
    # Keep the parent alive until the elevated child exits so release-bootstrap cleanup is safe.
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',("`"{0}`"" -f $PSCommandPath))
    return
}
& (Join-Path $PSScriptRoot 'main.ps1')

function Get-RSBSystemInfo {
    [CmdletBinding()]
    param()

    $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$cv.CurrentBuildNumber
    $family = if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
    $architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $processArchitecture = if ([Environment]::Is64BitProcess) { 'x64' } else { 'x86' }
    [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        DisplayName = $family
        RegistryProductName = $cv.ProductName
        Build = $build
        DisplayVersion = $cv.DisplayVersion
        Architecture = $architecture
        ProcessArchitecture = $processArchitecture
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
}

[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'RSBITToolkit.psd1') -Force -DisableNameChecking
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = Get-Content (Join-Path $root 'xaml\MainWindow.xaml') -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$find = { param($name) $window.FindName($name) }
$status = & $find 'StatusText'; $details = & $find 'DetailsText'; $apply = & $find 'ApplyButton'; $preflight = & $find 'PreflightButton'; $undo = & $find 'UndoButton'; $repair = & $find 'RepairButton'; $logs = & $find 'LogsButton'

function Set-UIResult([string]$text) {
    $window.Dispatcher.Invoke([action]{ $status.Text = $text; $details.Text = $text })
}

function Invoke-RSBBackground([scriptblock]$Work, [object[]]$Arguments = @()) {
    $apply.IsEnabled = $false; $preflight.IsEnabled = $false
    $status.Text = 'Working…'; $details.Text = 'Action is running in a background PowerShell instance. See Logs / History for persisted detail.'
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($Work.ToString()).AddArgument($root)
    foreach ($argument in $Arguments) { [void]$ps.AddArgument($argument) }
    $async = $ps.BeginInvoke()
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Add_Tick({
        if ($async.IsCompleted) {
            $timer.Stop(); $apply.IsEnabled = $true; $preflight.IsEnabled = $true
            try { $result = $ps.EndInvoke($async); Set-UIResult ($result | Out-String) }
            catch { Set-UIResult "FAILED: $($_.Exception.Message)" }
            finally { $ps.Dispose() }
        }
    })
    $timer.Start()
}

$preflight.Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; if (-not (Test-RSBElevation)) { throw 'Run elevated.' }; $i=Get-RSBInteractiveUser; $e=Get-RSBLocalIdentity $i; Get-RSBAccountState $e } })
$repair.Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Repair-RSBEmployeeAccount } })
$apply.Add_Click({
    $password1 = Read-Host 'Password for RSB IT Admin' -AsSecureString
    $password2 = Read-Host 'Confirm password for RSB IT Admin' -AsSecureString
    $b1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1); $b2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
    try { if ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1) -cne [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)) { throw 'Passwords do not match.' } }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2) }
    Invoke-RSBBackground { param($moduleRoot,$securePassword) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBBranchSecurityBaseline -Password $securePassword } @($password1)
})
$undo.Add_Click({
    $stateFile = Get-ChildItem (Join-Path (Initialize-RSBPaths).State '*.json') | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $stateFile) { Set-UIResult 'No state backup found.'; return }
    Invoke-RSBBackground { param($moduleRoot,$savedStatePath) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Undo-RSBBranchSecurityBaseline -StatePath $savedStatePath } @($stateFile.FullName)
})
$logs.Add_Click({ Start-Process explorer.exe (Initialize-RSBPaths).Logs })
(& $find 'TimeRepairButton').Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBWindowsTimeRepair } })
(& $find 'NetworkRepairButton').Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBNetworkRepair -Confirm:$false } })
(& $find 'SpoolerRepairButton').Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBPrintSpoolerRepair } })
(& $find 'DismRepairButton').Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBDismRepair } })
(& $find 'AdminVerifyButton').Add_Click({ Invoke-RSBBackground { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; $a=Get-LocalUser -Name 'RSB IT Admin' -ErrorAction Stop; Get-RSBAccountState ([pscustomobject]@{Name=$a.Name;Sid=$a.SID.Value;Enabled=$a.Enabled;ProfilePath=$null}) } })

$system = Get-RSBSystemInfo
(& $find 'ComputerText').Text = "$($system.ComputerName) · $($system.DisplayName) build $($system.Build)"
$window.ShowDialog() | Out-Null

[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'RSBITToolkit.psd1') -Force -DisableNameChecking
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = Get-Content (Join-Path $root 'xaml\MainWindow.xaml') -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$find = { param($name) $window.FindName($name) }
$status = & $find 'StatusText'; $details = & $find 'DetailsText'; $activityLog = & $find 'ActivityLogText'; $activityCounter = & $find 'ActivityCounterText'; $activityProgress = & $find 'ActivityProgressBar'
$apply = & $find 'ApplyButton'; $preflight = & $find 'PreflightButton'; $undo = & $find 'UndoButton'; $repair = & $find 'RepairButton'; $logs = & $find 'LogsButton'
$adminVerify = & $find 'AdminVerifyButton'; $timeRepair = & $find 'TimeRepairButton'; $networkRepair = & $find 'NetworkRepairButton'; $spoolerRepair = & $find 'SpoolerRepairButton'; $dismRepair = & $find 'DismRepairButton'
$actionButtons = @($apply, $preflight, $undo, $repair, $adminVerify, $timeRepair, $networkRepair, $spoolerRepair, $dismRepair)

function Set-UIResult([string]$text) {
    $window.Dispatcher.Invoke([action]{ $status.Text = $text; $details.Text = $text })
}

function Add-RSBActivity([string]$Text) {
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $activityLog.AppendText("[$timestamp] $Text$([Environment]::NewLine)")
    $activityLog.ScrollToEnd()
}

function Invoke-RSBBackground([string]$ActionName, [scriptblock]$Work, [object[]]$Arguments = @()) {
    foreach ($button in $actionButtons) { $button.IsEnabled = $false }
    $started = Get-Date
    $activityLog.Clear()
    $status.Text = "$ActionName — starting"
    $details.Text = 'The toolkit is checking prerequisites before making any changes.'
    $activityProgress.IsIndeterminate = $true
    $activityCounter.Text = 'Elapsed 00:00 • 1 activity entry'
    Add-RSBActivity "Started: $ActionName"
    Write-RSBLog -Message "Operator started '$ActionName' from the WPF interface." | Out-Null
    $paths = Initialize-RSBPaths
    $knownLineCounts = @{}
    Get-ChildItem -LiteralPath $paths.Logs -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object { $knownLineCounts[$_.FullName] = @(Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue).Count }
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($Work.ToString()).AddArgument($root)
    foreach ($argument in $Arguments) { [void]$ps.AddArgument($argument) }
    $async = $ps.BeginInvoke()
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Add_Tick({
        $elapsed = (Get-Date) - $started
        $entryCount = @($activityLog.Text -split [Environment]::NewLine | Where-Object { $_ }).Count
        $activityCounter.Text = ('Elapsed {0:mm\\:ss} • {1} activity {2}' -f $elapsed, $entryCount, $(if ($entryCount -eq 1) { 'entry' } else { 'entries' }))
        Get-ChildItem -LiteralPath $paths.Logs -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $started } | ForEach-Object {
            $lines = @(Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue)
            $previousCount = if ($knownLineCounts.ContainsKey($_.FullName)) { $knownLineCounts[$_.FullName] } else { 0 }
            if ($lines.Count -gt $previousCount) {
                $lines[$previousCount..($lines.Count - 1)] | ForEach-Object { Add-RSBActivity $_ }
            }
            $knownLineCounts[$_.FullName] = $lines.Count
        }
        if ($async.IsCompleted) {
            $timer.Stop(); foreach ($button in $actionButtons) { $button.IsEnabled = $true }; $activityProgress.IsIndeterminate = $false
            try { $result = $ps.EndInvoke($async); Set-UIResult ($result | Out-String); Add-RSBActivity "Completed: $ActionName" }
            catch { Set-UIResult "FAILED: $($_.Exception.Message)"; Add-RSBActivity "FAILED: $($_.Exception.Message)" }
            finally { $ps.Dispose() }
        }
    })
    $timer.Start()
}

$preflight.Add_Click({ Invoke-RSBBackground 'Preflight' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; if (-not (Test-RSBElevation)) { throw 'Run elevated.' }; $i=Get-RSBInteractiveUser; $e=Get-RSBLocalIdentity $i; Get-RSBAccountState $e } })
$repair.Add_Click({ Invoke-RSBBackground 'Employee membership repair' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Repair-RSBEmployeeAccount } })
$apply.Add_Click({
    $password1 = Read-Host 'Password for RSB IT Admin' -AsSecureString
    $password2 = Read-Host 'Confirm password for RSB IT Admin' -AsSecureString
    $b1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1); $b2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
    try { if ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1) -cne [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)) { throw 'Passwords do not match.' } }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2) }
    Invoke-RSBBackground 'Branch security baseline' { param($moduleRoot,$securePassword) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBBranchSecurityBaseline -Password $securePassword } @($password1)
})
$undo.Add_Click({
    $stateFile = Get-ChildItem (Join-Path (Initialize-RSBPaths).State '*.json') | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $stateFile) { Set-UIResult 'No state backup found.'; return }
    Invoke-RSBBackground 'Undo branch security baseline' { param($moduleRoot,$savedStatePath) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Undo-RSBBranchSecurityBaseline -StatePath $savedStatePath } @($stateFile.FullName)
})
$logs.Add_Click({ Start-Process explorer.exe (Initialize-RSBPaths).Logs })
$timeRepair.Add_Click({ Invoke-RSBBackground 'Windows Time repair' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBWindowsTimeRepair } })
$networkRepair.Add_Click({ Invoke-RSBBackground 'Network repair' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBNetworkRepair -Confirm:$false } })
$spoolerRepair.Add_Click({ Invoke-RSBBackground 'Print Spooler repair' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBPrintSpoolerRepair } })
$dismRepair.Add_Click({ Invoke-RSBBackground 'DISM / SFC repair' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBDismRepair } })
$adminVerify.Add_Click({ Invoke-RSBBackground 'RSB IT Admin verification' { param($moduleRoot) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; $a=Get-LocalUser -Name 'RSB IT Admin' -ErrorAction Stop; Get-RSBAccountState ([pscustomobject]@{Name=$a.Name;Sid=$a.SID.Value;Enabled=$a.Enabled;ProfilePath=$null}) } })

$system = Get-RSBSystemInfo
(& $find 'ComputerText').Text = "$($system.ComputerName) · $($system.DisplayName) build $($system.Build)"
$window.ShowDialog() | Out-Null

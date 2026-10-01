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

function Set-RSBActionButtons([bool]$Enabled) {
    foreach ($button in $actionButtons) { $button.IsEnabled = $Enabled }
}

function Start-RSBImmediateFeedback([string]$ActionName, [string]$Message) {
    Set-RSBActionButtons $false
    $activityLog.Clear()
    $status.Text = "$ActionName — $Message"
    $details.Text = 'The request was received. No security changes have started yet.'
    $activityProgress.IsIndeterminate = $true
    $activityCounter.Text = 'Waiting for IT input'
    Add-RSBActivity "Request received: $ActionName"
    $window.UpdateLayout()
}

function Test-RSBSecureStringsEqual([Security.SecureString]$First, [Security.SecureString]$Second) {
    $firstBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($First)
    $secondBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Second)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($firstBstr) -ceq [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secondBstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($firstBstr); [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secondBstr) }
}

function Get-RSBConfirmedPassword {
    [xml]$dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Confirm Branch Security Baseline" Width="460" SizeToContent="Height" WindowStartupLocation="CenterOwner" ResizeMode="NoResize" ShowInTaskbar="False" Background="#20252B" Foreground="#F4F7F9">
  <Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <TextBlock Text="Recovery administrator password" FontSize="20" FontWeight="SemiBold"/>
    <TextBlock Grid.Row="1" Margin="0,8,0,16" Text="This password is used only for this operation and is never written to logs or state." TextWrapping="Wrap" Foreground="#B8C4CE"/>
    <TextBlock Grid.Row="2" Text="Password"/><PasswordBox x:Name="PasswordOne" Grid.Row="3" Margin="0,6,0,12" Height="32"/>
    <TextBlock Grid.Row="4" Text="Confirm password"/><PasswordBox x:Name="PasswordTwo" Grid.Row="5" Margin="0,6,0,0" Height="32"/>
    <StackPanel Grid.Row="6" Margin="0,12,0,0"><TextBlock x:Name="PasswordError" Foreground="#FFB4AB" TextWrapping="Wrap"/><WrapPanel Margin="0,12,0,0"><Button x:Name="ConfirmButton" Content="Start baseline" IsDefault="True" MinWidth="120" Padding="14,8" Margin="0,0,8,0"/><Button x:Name="CancelButton" Content="Cancel" IsCancel="True" MinWidth="90" Padding="14,8"/></WrapPanel></StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object Xml.XmlNodeReader $dialogXaml
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    $dialog.Owner = $window
    $passwordOne = $dialog.FindName('PasswordOne'); $passwordTwo = $dialog.FindName('PasswordTwo'); $error = $dialog.FindName('PasswordError'); $confirm = $dialog.FindName('ConfirmButton')
    $result = [pscustomobject]@{ Password = $null }
    $confirm.Add_Click({
        if ($passwordOne.SecurePassword.Length -eq 0) { $error.Text = 'Enter the recovery administrator password.'; return }
        if (-not (Test-RSBSecureStringsEqual $passwordOne.SecurePassword $passwordTwo.SecurePassword)) { $error.Text = 'The passwords do not match. Try again.'; $passwordTwo.Clear(); $passwordTwo.Focus(); return }
        $result.Password = $passwordOne.SecurePassword.Copy(); $passwordOne.Clear(); $passwordTwo.Clear(); $dialog.DialogResult = $true
    })
    $dialog.Add_ContentRendered({ $passwordOne.Focus() })
    if ($dialog.ShowDialog() -eq $true) { return $result.Password }
    return $null
}

function Invoke-RSBBackground([string]$ActionName, [scriptblock]$Work, [object[]]$Arguments = @(), [switch]$AlreadyAcknowledged) {
    if (-not $AlreadyAcknowledged) {
        Start-RSBImmediateFeedback -ActionName $ActionName -Message 'starting'
    }
    else {
        $status.Text = "$ActionName — running preflight"
        $details.Text = 'Password confirmed. The toolkit is checking prerequisites before making any changes.'
        $activityCounter.Text = 'Elapsed 00:00 • 2 activity entries'
        Add-RSBActivity 'Password confirmation accepted; starting preflight.'
    }
    $started = Get-Date
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
            $timer.Stop(); Set-RSBActionButtons $true; $activityProgress.IsIndeterminate = $false
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
    Start-RSBImmediateFeedback -ActionName 'Branch security baseline' -Message 'awaiting password'
    $password = Get-RSBConfirmedPassword
    if ($null -eq $password) {
        $status.Text = 'Branch security baseline cancelled'; $details.Text = 'No security changes were made.'; $activityProgress.IsIndeterminate = $false; $activityCounter.Text = 'Cancelled'; Add-RSBActivity 'Cancelled before preflight.'; Set-RSBActionButtons $true; return
    }
    Invoke-RSBBackground 'Branch security baseline' { param($moduleRoot,$securePassword) Import-Module "$moduleRoot\RSBITToolkit.psd1" -Force -DisableNameChecking; Invoke-RSBBranchSecurityBaseline -Password $securePassword } @($password) -AlreadyAcknowledged
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

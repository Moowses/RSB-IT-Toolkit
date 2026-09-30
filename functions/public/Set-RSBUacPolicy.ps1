function Set-RSBUacPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    if ($PSCmdlet.ShouldProcess($path, 'Require administrator credentials on secure desktop')) {
        New-ItemProperty -Path $path -Name ConsentPromptBehaviorUser -PropertyType DWord -Value 1 -Force | Out-Null
        New-ItemProperty -Path $path -Name PromptOnSecureDesktop -PropertyType DWord -Value 1 -Force | Out-Null
    }
}

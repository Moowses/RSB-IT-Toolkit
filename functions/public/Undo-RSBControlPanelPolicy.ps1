function Undo-RSBControlPanelPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)]$ControlPanelOriginal)

    $path = $ControlPanelOriginal.Path
    if ($PSCmdlet.ShouldProcess($path, 'Restore employee Control Panel policy state')) {
        if ($ControlPanelOriginal.Exists) { New-Item -Path $path -Force | Out-Null; New-ItemProperty -Path $path -Name NoControlPanel -PropertyType DWord -Value $ControlPanelOriginal.Value -Force | Out-Null }
        elseif (Test-Path -LiteralPath $path) { Remove-ItemProperty -Path $path -Name NoControlPanel -ErrorAction SilentlyContinue }
    }
}

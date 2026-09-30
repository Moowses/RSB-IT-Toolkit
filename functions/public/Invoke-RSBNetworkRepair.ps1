function Invoke-RSBNetworkRepair {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('Network stack', 'Reset Winsock and IP stack')) {
        & netsh.exe winsock reset | ForEach-Object { Write-RSBLog -Message "Network: $_" }
        & netsh.exe int ip reset | ForEach-Object { Write-RSBLog -Message "Network: $_" }
    }
    [pscustomobject]@{ Status = 'SUCCESS'; RebootRequired = $true }
}

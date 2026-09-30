function Invoke-RSBPrintSpoolerRepair {
    [CmdletBinding()]
    param()
    Restart-Service -Name Spooler -Force -ErrorAction Stop
    Write-RSBLog -Level SUCCESS -Message 'Print Spooler restarted.'
    [pscustomobject]@{ Status = 'SUCCESS'; RebootRequired = $false }
}

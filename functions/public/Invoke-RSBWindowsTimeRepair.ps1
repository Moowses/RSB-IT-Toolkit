function Invoke-RSBWindowsTimeRepair {
    [CmdletBinding()]
    param()
    Start-Service w32time -ErrorAction SilentlyContinue
    & w32tm.exe /resync /force 2>&1 | ForEach-Object { Write-RSBLog -Message "Windows Time: $_" }
    return [pscustomobject]@{ Status = if ($LASTEXITCODE -eq 0) { 'SUCCESS' } else { 'WARNING' }; RebootRequired = $false }
}

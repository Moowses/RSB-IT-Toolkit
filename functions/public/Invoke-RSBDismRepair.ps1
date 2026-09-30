function Invoke-RSBDismRepair {
    [CmdletBinding()]
    param()
    & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | ForEach-Object { Write-RSBLog -Message "DISM: $_" }
    $dismExit = $LASTEXITCODE
    & sfc.exe /scannow 2>&1 | ForEach-Object { Write-RSBLog -Message "SFC: $_" }
    $sfcExit = $LASTEXITCODE
    [pscustomobject]@{ Status = if ($dismExit -eq 0 -and $sfcExit -eq 0) { 'SUCCESS' } else { 'WARNING' }; RebootRequired = ($dismExit -eq 3010 -or $sfcExit -eq 3010) }
}

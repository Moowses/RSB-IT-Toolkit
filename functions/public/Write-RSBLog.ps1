function Write-RSBLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','FAILED','ROLLBACK')][string]$Level = 'INFO',
        [string]$TransactionId = 'session',
        [string]$LogPath
    )

    if (-not $LogPath) {
        $paths = Initialize-RSBPaths
        $LogPath = Join-Path $paths.Logs ("{0:yyyyMMdd}-{1}.log" -f (Get-Date), $TransactionId)
    }
    # Callers must pass operational facts only: this function deliberately has no password parameter.
    $line = '{0:o} [{1}] [{2}] {3}' -f [DateTime]::UtcNow, $Level, $TransactionId, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Verbose $line
    return $line
}

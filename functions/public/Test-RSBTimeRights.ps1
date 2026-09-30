function Test-RSBTimeRights {
    [CmdletBinding()]
    param()
    $temporary = Join-Path $env:TEMP ("RSB-time-rights-{0}.inf" -f [guid]::NewGuid().Guid)
    try {
        & secedit.exe /export /cfg $temporary /quiet | Out-Null
        $text = Get-Content -LiteralPath $temporary -Raw
        foreach ($right in @('SeSystemtimePrivilege','SeTimeZonePrivilege')) {
            $line = ($text -split "`r?`n" | Where-Object { $_ -match ('^' + $right + '\s*=') } | Select-Object -First 1)
            if (-not $line -or $line -notmatch 'S-1-5-32-544' -or $line -notmatch 'S-1-5-19') { return $false }
        }
        return $true
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

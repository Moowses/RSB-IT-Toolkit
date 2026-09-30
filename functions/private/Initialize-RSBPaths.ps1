function Initialize-RSBPaths {
    [CmdletBinding()]
    param()

    $root = Join-Path $env:ProgramData 'RSB-IT'
    if ([string]::IsNullOrWhiteSpace($env:ProgramData)) { $root = Join-Path $env:TEMP 'RSB-IT' }
    $paths = [ordered]@{
        Root = $root
        Logs = Join-Path $root 'Logs'
        State = Join-Path $root 'State'
    }
    foreach ($path in $paths.Values) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
    return [pscustomobject]$paths
}

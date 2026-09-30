function Set-RSBTimeRights {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$PolicyBackupPath)

    if (-not (Test-Path -LiteralPath $PolicyBackupPath)) { throw 'Security-policy backup is missing.' }
    $config = Get-Content (Join-Path $PSScriptRoot '..\..\config\security-baseline.json') -Raw | ConvertFrom-Json
    $contents = Get-Content -LiteralPath $PolicyBackupPath
    foreach ($right in $config.timeRights) {
        $replacement = "$right = *S-1-5-32-544,*S-1-5-19"
        $match = '^' + [regex]::Escape($right) + '\s*='
        if ($contents -match $match) { $contents = $contents | ForEach-Object { if ($_ -match $match) { $replacement } else { $_ } } }
        else { $contents += $replacement }
    }
    $applyPath = [IO.Path]::ChangeExtension($PolicyBackupPath, '.apply.inf')
    Set-Content -LiteralPath $applyPath -Value $contents -Encoding Unicode
    if ($PSCmdlet.ShouldProcess('Local security policy', 'Set system time/time-zone rights to Administrators and LOCAL SERVICE')) {
        & secedit.exe /configure /db (Join-Path $env:TEMP 'RSB-IT-security.sdb') /cfg $applyPath /areas USER_RIGHTS /quiet | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "secedit failed applying user rights (exit $LASTEXITCODE)." }
    }
    return $applyPath
}

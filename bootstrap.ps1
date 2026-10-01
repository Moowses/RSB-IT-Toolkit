[CmdletBinding()]
param(
    [ValidateSet('stable','dev')][string]$Channel = 'stable',
    [string]$Version
)

$repo = 'Moowses/rsb-it-toolkit'
$release = if ($Version) { "https://github.com/$repo/releases/download/$Version" } elseif ($Channel -eq 'stable') { "https://github.com/$repo/releases/latest/download" } else { "https://github.com/$repo/releases/download/dev" }
$asset = 'RSB-IT-Toolkit.zip'
$work = Join-Path $env:TEMP ("RSB-IT-Toolkit-" + [guid]::NewGuid().Guid)
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $zip = Join-Path $work $asset; $manifest = Join-Path $work 'SHA256SUMS.txt'
    try {
        Invoke-WebRequest -Uri "$release/$asset" -OutFile $zip -UseBasicParsing -ErrorAction Stop
        Invoke-WebRequest -Uri "$release/SHA256SUMS.txt" -OutFile $manifest -UseBasicParsing -ErrorAction Stop
    } catch {
        throw "No approved RSB IT Toolkit '$Channel' release is available. Do not continue on this PC. Ask IT for an approved tagged release or use the trusted checkout runbook. Original download error: $($_.Exception.Message)"
    }
    $expected = ((Get-Content $manifest | Where-Object { $_ -match [regex]::Escape($asset) }) -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $expected -or $actual -ne $expected) { throw 'Release SHA256 validation failed; no toolkit files were run.' }
    Expand-Archive -LiteralPath $zip -DestinationPath $work -Force
    $entry = Get-ChildItem -Path $work -Filter start.ps1 -Recurse | Select-Object -First 1
    if (-not $entry) { throw 'Verified artifact does not contain scripts/start.ps1.' }
    Write-Host "Starting verified RSB IT Toolkit release ($Channel)."
    & $entry.FullName
} finally {
    # Keep downloaded evidence while process is active only; no credentials are involved.
    if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}

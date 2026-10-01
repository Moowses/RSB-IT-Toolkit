[CmdletBinding()]
param(
    [ValidateSet('stable','dev')][string]$Channel = 'stable',
    [string]$Version
)

$repo = 'Moowses/rsb-it-toolkit'
$asset = 'RSB-IT-Toolkit.zip'
$work = Join-Path $env:TEMP ("RSB-IT-Toolkit-" + [guid]::NewGuid().Guid)
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    try {
        if ($Version) { $release = "https://github.com/$repo/releases/download/$Version" }
        elseif ($Channel -eq 'stable') { $release = "https://github.com/$repo/releases/latest/download" }
        else {
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=20" -Headers @{ 'User-Agent' = 'RSB-IT-Toolkit-Bootstrap' } -ErrorAction Stop
            $preview = @($releases | Where-Object { $_.prerelease -and -not $_.draft } | Select-Object -First 1)
            if (-not $preview) { throw 'No published engineering-preview release was found.' }
            $release = "https://github.com/$repo/releases/download/$($preview[0].tag_name)"
        }
        $zip = Join-Path $work $asset; $manifest = Join-Path $work 'SHA256SUMS.txt'
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
    # The bootstrap itself may be invoked through Invoke-Expression on a device with a restrictive policy.
    # Run the verified extracted script in a process-scoped Bypass host rather than asking the technician to alter machine policy.
    $powershellHost = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellHost)) { throw 'Windows PowerShell 5.1 was not found.' }
    & $powershellHost -NoProfile -ExecutionPolicy Bypass -File $entry.FullName
    if ($LASTEXITCODE -ne 0) { throw "RSB IT Toolkit exited with code $LASTEXITCODE." }
} finally {
    # Keep downloaded evidence while process is active only; no credentials are involved.
    if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}

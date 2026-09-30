[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'))

$stage = Join-Path $env:TEMP ("rsb-it-toolkit-stage-" + [guid]::NewGuid().Guid)
$asset = Join-Path $OutputDirectory 'RSB-IT-Toolkit.zip'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    Get-ChildItem -Path $PSScriptRoot -Force | Where-Object { $_.Name -notin @('.git','dist','tests','.github') } | Copy-Item -Destination $stage -Recurse -Force
    if (Test-Path $asset) { Remove-Item -LiteralPath $asset -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $asset -Force
    $hash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
    "{0}  RSB-IT-Toolkit.zip" -f $hash | Set-Content (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ASCII
    Write-Host "Built $asset"
} finally { if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }

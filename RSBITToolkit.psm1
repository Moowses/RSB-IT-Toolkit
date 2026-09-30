$moduleRoot = Split-Path -Parent $PSCommandPath
Get-ChildItem -Path (Join-Path $moduleRoot 'functions/private') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem -Path (Join-Path $moduleRoot 'functions/public') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function *

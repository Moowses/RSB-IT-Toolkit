function Get-RSBInteractiveUser {
    [CmdletBinding()]
    param()

    # Do not use Win32_ComputerSystem/CIM: it fails on known branch endpoints.
    $candidates = @()
    try {
        $explorers = Get-Process -Name explorer -IncludeUserName -ErrorAction Stop | Where-Object { $_.UserName }
        foreach ($explorer in $explorers) {
            $shortName = ($explorer.UserName -split '\\')[-1]
            $candidates += [pscustomobject]@{ Name = $shortName; QualifiedName = $explorer.UserName; Source = 'Explorer'; SessionId = $explorer.SessionId }
        }
    } catch { }

    if ($candidates.Count -eq 0) {
        $query = & quser 2>$null
        foreach ($line in $query | Select-Object -Skip 1) {
            if ($line -match '^\s*>?\s*(?<user>\S+)\s+\S+\s+(?<id>\d+)\s+Active') {
                $candidates += [pscustomobject]@{ Name = $Matches.user; QualifiedName = $Matches.user; Source = 'query user'; SessionId = [int]$Matches.id }
            }
        }
    }
    $candidates = @($candidates | Sort-Object QualifiedName,SessionId -Unique)
    if ($candidates.Count -ne 1) { throw "Expected exactly one safe active interactive user; found $($candidates.Count)." }
    return $candidates[0]
}

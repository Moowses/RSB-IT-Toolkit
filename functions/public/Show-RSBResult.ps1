function Show-RSBResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Result)
    return ($Result | ConvertTo-Json -Depth 6)
}

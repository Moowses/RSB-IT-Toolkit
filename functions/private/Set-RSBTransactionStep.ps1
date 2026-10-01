function Set-RSBTransactionStep {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Status)

    $step = [pscustomobject]@{ Name = $Name; Status = $Status; TimestampUtc = [DateTime]::UtcNow.ToString('o') }
    $State.Steps += $step
    Write-RSBLog -TransactionId $State.TransactionId -Message "Transaction step '$Name' is $Status." | Out-Null
    return $step
}

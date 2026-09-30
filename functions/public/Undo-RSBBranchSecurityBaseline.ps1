function Undo-RSBBranchSecurityBaseline {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    return Restore-RSBStateBackup -StatePath $StatePath
}

function Repair-RSBEmployeeAccount {
    [CmdletBinding()]
    param()
    $employee = Get-RSBLocalIdentity -InteractiveUser (Get-RSBInteractiveUser)
    return Ensure-RSBStandardUser -Employee $employee
}

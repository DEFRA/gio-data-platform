[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$miLoginName,

    [Parameter(Mandatory = $false)]
    [bool]$createStagingUser = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$slotName = "staging",

    [Parameter(Mandatory = $true)]
    [string]$aadUser,

    [Parameter(Mandatory = $true)]
    [string]$aadUserPassword,

    [Parameter(Mandatory = $true)]
    [string]$connectionStrings
)

$ErrorActionPreference = "Stop"

# Common function for DB Set-User
function Set-DatabaseUser
{  
    [CmdletBinding()]
    param ($miName, $dbServer, $databaseName, $pscredential)

    Write-Output "Creating MI User: $miName in DB: $databaseName on Server: $dbServer"

    $Query = "IF NOT EXISTS(SELECT principal_id FROM sys.database_principals WHERE name = '$miName') BEGIN CREATE USER [$miName] FROM EXTERNAL PROVIDER; `
    EXEC sp_addrolemember N'db_datareader', '$miName'; `
    EXEC sp_addrolemember N'db_datawriter', '$miName'; `
    GRANT EXECUTE TO [$miName]; `
    END"

    Invoke-DbaQuery -SqlInstance $dbServer -Database $databaseName -SqlCredential $pscredential -Query $Query -EnableException
    Write-Output "Successfully created user: $miName with permissions data reader, writer and execute permissions"
}

try {
    [System.Security.SecureString]$pwd =  ConvertTo-SecureString $aadUserPassword -AsPlainText -Force

    # DB Admin Login AAD account
    $pscredential = New-Object -TypeName System.Management.Automation.PSCredential($aadUser, $pwd)

    $connections = ConvertFrom-Json $connectionStrings
    foreach($conn in $connections) {
        Write-Debug "ConnectionString: $conn"
        if ($conn.type -eq 'sqlazure') {
            $value = $conn.value.Split(";")
            $server = ((ConvertFrom-StringData $value[0]).Values -replace 'tcp:','') -replace ',1433',''
            $database = (ConvertFrom-StringData $value[1]).Values

            Set-DatabaseUser    -miName $miLoginName `
                                -dbServer $server `
                                -databaseName $database `
                                -pscredential $pscredential

            # Create if staging user is required
            If ($createStagingUser) {
                $StagingMiLoginName = "$miLoginName/slots/$slotName"
                Write-Output "Staging Slot = TRUE..."
                Write-Output "Creating Staging Slot User: $StagingMiLoginName for slot name: $slotName"

                Set-DatabaseUser    -miName $StagingMiLoginName `
                                    -dbServer $server `
                                    -databaseName $database `
                                    -pscredential $pscredential
            }
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
}
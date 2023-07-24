[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$miLoginName,

    [Parameter(Mandatory = $false)]
    [string]$serviceBusName,

    [Parameter(Mandatory = $false)]
    [string[]]$serviceBusRoles = @('Azure Service Bus Data Sender', 'Azure Service Bus Data Receiver'),

    [Parameter(Mandatory = $false)]
    [string]$keyVaultName,

    [Parameter(Mandatory = $false)]
    [string[]]$keyVaultPermissions = @('get', 'list')
)

$stagingSlot = Get-AzADServicePrincipal -DisplayName $miLoginName
Write-Output $stagingSlot

if (($null -ne $serviceBusName) -and ($serviceBusName -ne '')) {
    foreach ($serviceBusRole in $serviceBusRoles) {
        $role = Get-AzRoleDefinition -Name $serviceBusRole
        $serviceBus = Get-AzServiceBusNamespace -Name $serviceBusName | Where-Object Name -eq $serviceBusName
        $roleAssignment = Get-AzRoleAssignment -ObjectId $stagingSlot.Id -RoleDefinitionName $role.Name -Scope $serviceBus.Id -ErrorAction SilentlyContinue
        if ($null -ne $roleAssignment) {
            Remove-AzRoleAssignment -ObjectId $stagingSlot.Id -RoleDefinitionName $role.Name -Scope $serviceBus.Id
        }
        New-AzRoleAssignment -ObjectId $stagingSlot.Id -RoleDefinitionName $role.Name -Scope $serviceBus.Id
    }
}

if (($null -ne $keyVaultName) -and ($keyVaultName -ne '')) {
    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $stagingSlot.Id -PermissionsToSecrets $keyVaultPermissions -PassThru
}

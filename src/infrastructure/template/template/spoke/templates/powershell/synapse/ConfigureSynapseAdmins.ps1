[CmdletBinding()] 
param(
    [string][Parameter(Mandatory=$true)] $SynapseWorkspaceName,

    [string][Parameter(Mandatory=$true, ParameterSetName="KnownId")] $SynapseAdminRole,
    [string][Parameter(Mandatory=$true, ParameterSetName="KnownId")] $SynapseAdminRoleId,
    
    [string][Parameter(Mandatory=$true, ParameterSetName="ManagedIdentity")] $ResourceName,

    [string][Parameter(Mandatory=$false)] $SynapseRoleName = "Synapse Administrator"
)
$ErrorActionPreference = "Stop"
[Net.ServicepointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

Import-Module Az.Synapse

if ("" -ne $ResourceName) {
    $mi = Get-AzADServicePrincipal -DisplayName $ResourceName
    $SynapseAdminRoleId = $mi.Id
    $SynapseAdminRole = $ResourceName
}

$role = Get-AzSynapseRoleAssignment -WorkspaceName $SynapseWorkspaceName -RoleDefinitionName "$SynapseRoleName" -ObjectId $SynapseAdminRoleId
if ($null -eq $role) {
    New-AzSynapseRoleAssignment -WorkspaceName $SynapseWorkspaceName -RoleDefinitionName "$SynapseRoleName" -ObjectId $SynapseAdminRoleId
}
else {
    Write-Host "Role $SynapseRoleName is already set up for $SynapseAdminRole in $SynapseWorkspaceName"
}


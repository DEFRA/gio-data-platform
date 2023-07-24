param synapseWorkspace object
param contributerRoleID string
param name string
param dataContributerGuid string
param dataContributerGuidAdo string
param dataContribGuidRG string
param deploymentPrincipalId string
param storageBlobDataContributorGroupRoleId string
param location string

resource dataContributorRoleAssignments 'Microsoft.Storage/storageAccounts/providers/roleAssignments@2018-09-01-preview' = {
  name: '${name}/Microsoft.Authorization/${dataContributerGuid}'
  location: location
  properties: {
    roleDefinitionId: contributerRoleID
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dataContributerGuidAdoRoleAssignments 'Microsoft.Storage/storageAccounts/providers/roleAssignments@2018-09-01-preview' = {
  name: '${name}/Microsoft.Authorization/${dataContributerGuidAdo}'
  location: location
  properties: {
    roleDefinitionId: contributerRoleID
    principalId: deploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dataContribGuidRGRoleAssignments 'Microsoft.Storage/storageAccounts/providers/roleAssignments@2018-09-01-preview' = {
  name: '${name}/Microsoft.Authorization/${dataContribGuidRG}'
  location: location
  properties: {
    roleDefinitionId: contributerRoleID
    principalId: storageBlobDataContributorGroupRoleId
    principalType: 'Group'
  }
}

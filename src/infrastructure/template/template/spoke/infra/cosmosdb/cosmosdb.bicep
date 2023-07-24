param accountName string = 'dev__PRJ-LOWER__infco1002'
param dbPublishedName string = '__PRJ-LOWER__PublishedSet'
param dbPublishedThroughputMax string = '10000'
param dbLookupName string = '__PRJ-LOWER__LookupSet'
param keyVaultRG string
param keyVaultName string
param envId string
param dbLookupThroughputMax string = '10000'
param createdDate string = utcNow('yyyy-MM-dd')
param environment string
param customTags object
param freeTier string = 'true'
param deploymentPrincipalId string
param synapseWorkspaceName string
param publicNetworkAccess string 
param cosmosPrivateEndpointDNSZone string
param cosmosPrivateEndpointNamesPrimary object
param __PRJ__Vnet object
param privateDnsResourceGroups object
param location string = resourceGroup().location
param buildAgentIPAddress string
param prj string
param primaryRegion string
param secondaryRegion string


var defaultTags = {
  ServiceCode: '__PRJ__'
  ServiceName: '__PRJ__'
  ServiceType: 'LOB'
  CreatedDate: createdDate
  Environment: environment
  Tier: 'OTHER'
  Location: location
}
var locations = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: secondaryRegion
    failoverPriority: 1
    isZoneRedundant: false
  }
]

var buildAgentIPAddress_var = split(buildAgentIPAddress, ';')
var cosmosDbContributorRoleID = '5bd9cd88-fe45-4216-938b-f97437e15450'
var uniqueCosmosDbContribGuid = guid(databaseAccounts.id, cosmosDbContributorRoleID, resourceId('Microsoft.Synapse/workspaces', toLower(synapseWorkspaceName)))
var uniqueCosmosDbContribGuidAdo = guid(databaseAccounts.id, cosmosDbContributorRoleID, deploymentPrincipalId)
var sqlContributorRoleId = '00000000-0000-0000-0000-000000000002'
var sqlRoleAssignmentId = guid(databaseAccounts.id, sqlContributorRoleId, resourceId('Microsoft.Synapse/workspaces', toLower(synapseWorkspaceName)))
var publicNetworkAccessvar = ((environment == 'pre' || environment == 'prd') ? 'Disabled' : 'Enabled' )
resource databaseAccounts 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: toLower(accountName)
  location: location
  tags: union(defaultTags, customTags)
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'None'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccessvar
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: bool(freeTier)
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: locations
    cors: []
    capabilities: []
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
      }
    }
    networkAclBypassResourceIds: []
    ipRules: [for (item, i) in split(buildAgentIPAddress, ';'): {
      ipAddressOrRange: item
    }]
  }
}

resource sqlDbPublishedName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: databaseAccounts
  name: dbPublishedName
  properties: {
    resource: {
      id: dbPublishedName
    }
    options: {
      autoscaleSettings: {
        maxThroughput: int(dbPublishedThroughputMax)
      }
    }
  }
}

resource sqlDbLookupName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: databaseAccounts
  name: dbLookupName
  properties: {
    resource: {
      id: dbLookupName
    }
    options: {
      autoscaleSettings: {
        maxThroughput: int(dbLookupThroughputMax)
      }
    }
  }
}
resource healthCheckContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: sqlDbPublishedName
  name: 'HealthCheck'
  properties: {
    resource: {
      id: 'HealthCheck'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}
resource readerSqlRoleDefinitions 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-06-15' = {
  parent: databaseAccounts
  name: '00000000-0000-0000-0000-000000000001'
  properties: {
    roleName: 'Cosmos DB Built-in Data Reader'
    type: 'BuiltInRole'
    assignableScopes: [
      databaseAccounts.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
        ]
        notDataActions: []
      }
    ]
  }
}

resource contributerSqlRoleDefinitions 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-06-15' = {
  parent: databaseAccounts
  name: sqlContributorRoleId
  properties: {
    roleName: 'Cosmos DB Built-in Data Contributor'
    type: 'BuiltInRole'
    assignableScopes: [
      databaseAccounts.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
        notDataActions: []
      }
    ]
  }
}

module KeyVaultSecretsDeploy './keyVaultSecrets.bicep' = {
  name: 'KeyVaultSecretsDeploy'
  scope: resourceGroup(keyVaultRG)
  params: {
    resourceId: resourceId(resourceGroup().name, 'Microsoft.DocumentDB/databaseAccounts', toLower(accountName))
    keyVaultName: keyVaultName
    envId: envId
    prj: prj
  }
  dependsOn: [
    databaseAccounts
  ]
}

resource roleAssignmentsUniqueCosmosDbContribGuidAdo 'Microsoft.DocumentDB/databaseAccounts/providers/roleAssignments@2018-09-01-preview' = {
  name: '${toLower(accountName)}/Microsoft.Authorization/${uniqueCosmosDbContribGuidAdo}'
  location: location
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cosmosDbContributorRoleID)
    principalId: deploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentsUniqueCosmosDbContribGuid 'Microsoft.DocumentDB/databaseAccounts/providers/roleAssignments@2018-09-01-preview' = {
  name: '${toLower(accountName)}/Microsoft.Authorization/${uniqueCosmosDbContribGuid}'
  location: location
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cosmosDbContributorRoleID)
    principalId: reference('Microsoft.Synapse/workspaces/${toLower(synapseWorkspaceName)}', '2019-06-01-preview', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource accountName_sqlRoleAssignmentId 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-04-15' = {
  parent: databaseAccounts
  name: sqlRoleAssignmentId
  properties: {
    roleDefinitionId: contributerSqlRoleDefinitions.id
    principalId: reference('Microsoft.Synapse/workspaces/${toLower(synapseWorkspaceName)}', '2019-06-01-preview', 'Full').identity.principalId
    scope: databaseAccounts.id
  }
}

resource cosmosPrivateEndpointNamesPrimary_primary 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: cosmosPrivateEndpointNamesPrimary.primary
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: cosmosPrivateEndpointNamesPrimary.primary
        properties: {
          privateLinkServiceId: databaseAccounts.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(__PRJ__Vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', __PRJ__Vnet.name, __PRJ__Vnet.peSubnet)
    }
    customDnsConfigs: []
  }
}

output privateEndpointDNSRecords array = [
  {
    zone: cosmosPrivateEndpointDNSZone
    record: toLower(accountName)
    id: cosmosPrivateEndpointNamesPrimary_primary.id
    resourceGroup: privateDnsResourceGroups.primary
    region: location
  }
]

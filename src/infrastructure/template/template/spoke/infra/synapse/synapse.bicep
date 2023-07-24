param name string
param defaultDataLakeStorageAccountName string
param environment string
param createdDate string = utcNow('yyyy-MM-dd')
param defaultDataLakeStorageFilesystemName string
param poolSizeSku string
param sqlPoolName string
param sparkPoolName string
param dotnetSparkPoolName string
param sqlAdministratorLogin string

@secure()
param sqlAdministratorLoginPassword string

@allowed([
  'default'
  ''
])
param managedVirtualNetwork string
param preventDataExfiltration bool = false
param storageAccessTier string
param customTags object
param customTagsDataLake object
param customTagsStorageAccount object
param storageAccountType string
param storageIsHnsEnabled bool
param sparkAutoScaleEnabled bool = false
param sparkMinNodeCount int = 1
param sparkMaxNodeCount int = 5
param sparkNodeCount string = '3'
param sparkNodeSizeFamily string = 'MemoryOptimized'
param sparkNodeSize string = 'Small'
param sparkAutoPauseEnabled bool = false
param sparkAutoPauseDelayInMinutes int = 120
param sparkVersion string = '2.4'
param dotnetSparkVersion string = '2.4'
param sparkConfigPropertiesFileName string = ''
param sparkConfigPropertiesContent string = ''
param sessionLevelPackagesEnabled bool = true
param createSQLPool bool = false
param createSparkCluster bool = false
param vaultName string
param vaultRG string
param buildAgentIPAddress string
param deploymentPrincipalId string
param storageBlobDataContributorGroupRoleId string
param dfsPrivateEndpointDNSZone string
param blobPrivateEndpointDNSZone string
param dfsPrivateEndpointNamesPrimary object
param blobPrivateEndpointNamesPrimary object
param __PRJ-LOWER__Vnet object
param privateDnsResourceGroups object
param synapsePrivateEndpointNamesPrimary object
param synapsePrivateEndpointDNSZone string
param actionGroupsOperationsTeamname string
param azureAdAdminLogin string
param azureAdAdminSsid string

@description('List of log diagnostic events to capture from Synapse WS and send to log analytics')
param synapseWsDiagLogs array = [
  'SynapseRbacOperations'
  'GatewayApiRequests'
  'BuiltinSqlReqsEnded'
  'IntegrationPipelineRuns'
  'IntegrationActivityRuns'
  'IntegrationTriggerRuns'
]
param logAnalyticsWorkspace string
param location string = resourceGroup().location
param defaultDataLakeStorageAccountUrlSuffix string 

var buildAgentIPAddress_var = split(buildAgentIPAddress, ';')
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var defaultDataLakeStorageAccountUrl = 'https://${toLower(defaultDataLakeStorageAccountName)}${defaultDataLakeStorageAccountUrlSuffix}'
var uniqueDataContribGuid = guid(storageAccounts.id, storageBlobDataContributorRoleID, workspaces.id)
var uniqueDataContribGuidAdo = guid(storageAccounts.id, storageBlobDataContributorRoleID, deploymentPrincipalId)
var uniqueDataContribGuidRG = guid(storageAccounts.id, storageBlobDataContributorRoleID, storageBlobDataContributorGroupRoleId)
var scheduledqueryrulesLocation  = 'northeurope'
var defaultTags = {
  ServiceCode: '__PRJ__'
  ServiceName: '__PRJ__'
  ServiceType: 'LOB'
  CreatedDate: createdDate
  Environment: environment
  Tier: 'OTHER'
  Location: location
}
var managedVnetSettings = {
  preventDataExfiltration: preventDataExfiltration
  allowedAadTenantIdsForLinking: []
}

resource firewallRules 'Microsoft.Synapse/workspaces/firewallRules@2019-06-01-preview' = [for (item, i) in buildAgentIPAddress_var: {
  name: '${toLower(name)}/BuildAgent${i}'
  properties: {
    startIpAddress: split(item, '/')[0]
    endIpAddress: split(item, '/')[0]
  }
  dependsOn: [
    workspaces
  ]
}]

resource workspaces 'Microsoft.Synapse/workspaces@2021-03-01' = {
  name: toLower(name)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: defaultDataLakeStorageAccountUrl
      filesystem: toLower(defaultDataLakeStorageFilesystemName)
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    managedVirtualNetwork: managedVirtualNetwork
    connectivityEndpoints: {
      dev: 'https://${toLower(name)}.dev.azuresynapse.net'
      sqlOnDemand: '${toLower(name)}-ondemand.sql.azuresynapse.net'
      sql: '${toLower(name)}.sql.azuresynapse.net'
    }
    managedResourceGroupName: '${resourceGroup().name}-managedsynapse'
    managedVirtualNetworkSettings: managedVnetSettings
  }
  tags: union(defaultTags, customTags)
  dependsOn: [
    storageAccounts
  ]
}

resource azureAdAdmin 'Microsoft.Synapse/workspaces/administrators@2021-06-01' = {
  name: 'activeDirectory'
  parent: workspaces
  properties: {
    administratorType: 'ActiveDirectory'
    login: azureAdAdminLogin
    sid: azureAdAdminSsid
    tenantId: subscription().tenantId
  }
}

resource managedIdentitySqlControlSettings 'Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings@2019-06-01-preview' = {
  parent: workspaces
  name: 'default'
  properties: {
    grantSqlControlToManagedIdentity: {
      desiredState: 'Enabled'
    }
  }
}

resource synapseIntegrationRuntimes 'Microsoft.Synapse/workspaces/integrationRuntimes@2019-06-01-preview' = {
  parent: workspaces
  name: 'IntegrationRuntime__PRJ__01'
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'MemoryOptimized'
          coreCount: 16
          timeToLive: 30
          cleanup: false
        }
        copyComputeScaleProperties: {
           dataIntegrationUnit: 32
           timeToLive: 60
        }
        pipelineExternalComputeScaleProperties: {
           timeToLive: 60
        }
      }
    }
  }
}
module storageRoleDeploymentResource './storageRoleDeploymentResource.bicep' = {
  name: 'StorageRoleDeploymentResource'
  scope: resourceGroup(subscription().subscriptionId, resourceGroup().name)
  params: {
    synapseWorkspace: reference('Microsoft.Synapse/workspaces/${toLower(name)}', '2019-06-01-preview', 'Full')
    contributerRoleID: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
    name: toLower(defaultDataLakeStorageAccountName)
    dataContributerGuid: uniqueDataContribGuid
    dataContributerGuidAdo: uniqueDataContribGuidAdo
    dataContribGuidRG: uniqueDataContribGuidRG
    deploymentPrincipalId: deploymentPrincipalId
    storageBlobDataContributorGroupRoleId: storageBlobDataContributorGroupRoleId
    location:location
  }
}

resource storageAccounts 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: toLower(defaultDataLakeStorageAccountName)
  location: location
  properties: {
    accessTier: storageAccessTier
    supportsHttpsTrafficOnly: true
    isHnsEnabled: storageIsHnsEnabled
    networkAcls: {
      virtualNetworkRules: []
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  tags: union(defaultTags, customTagsDataLake)
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${toLower(defaultDataLakeStorageAccountName)}/default/${toLower(defaultDataLakeStorageFilesystemName)}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts
  ]
}

module synapseAccessPolicies './synapseAccessPolicies.bicep' = {
  name: 'SynapseAccessPolicies'
  scope: resourceGroup(vaultRG)
  params: {
    workSpaceName: reference(resourceId(resourceGroup().name, 'Microsoft.Synapse/workspaces/', toLower(name)), '2019-06-01-preview', 'Full')
    vaultName: vaultName
  }
  dependsOn: [
    workspaces
  ]
}

resource blobprivateEndpoints 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: blobPrivateEndpointNamesPrimary.primary
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: blobPrivateEndpointNamesPrimary.primary
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts', defaultDataLakeStorageAccountName)
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(__PRJ-LOWER__Vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', __PRJ-LOWER__Vnet.name, __PRJ-LOWER__Vnet.peSubnet)
    }
    customDnsConfigs: []
  }
  dependsOn: [
    storageAccounts
  ]
}

resource dfsPrivateEndpoints 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: dfsPrivateEndpointNamesPrimary.primary
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: dfsPrivateEndpointNamesPrimary.primary
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts', defaultDataLakeStorageAccountName)
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(__PRJ-LOWER__Vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', __PRJ-LOWER__Vnet.name, __PRJ-LOWER__Vnet.peSubnet)
    }
    customDnsConfigs: []
  }
  dependsOn: [
    storageAccounts
  ]
}

resource sqlPools 'Microsoft.Synapse/workspaces/sqlPools@2021-03-01' = if (createSQLPool) {
  parent: workspaces
  location: location
  tags: union(defaultTags, customTags)
  name: sqlPoolName
  sku: {
    name: poolSizeSku
  }
  properties: {
    createMode: 'Default'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource bigDataPools 'Microsoft.Synapse/workspaces/bigDataPools@2021-03-01' = if (createSparkCluster) {
  parent: workspaces
  name: sparkPoolName
  location: location
  tags: union(defaultTags, customTags)
  properties: {
    nodeCount: int(sparkNodeCount)
    nodeSizeFamily: sparkNodeSizeFamily
    nodeSize: sparkNodeSize
    autoScale: {
      enabled: sparkAutoScaleEnabled
      minNodeCount: sparkMinNodeCount
      maxNodeCount: sparkMaxNodeCount
    }
    autoPause: {
      enabled: sparkAutoPauseEnabled
      delayInMinutes: sparkAutoPauseDelayInMinutes
    }
    sparkVersion: sparkVersion
    sparkConfigProperties: {
      filename: sparkConfigPropertiesFileName
      content: sparkConfigPropertiesContent
    }
    sessionLevelPackagesEnabled: sessionLevelPackagesEnabled
  }
}

resource dotnetBigDataPools 'Microsoft.Synapse/workspaces/bigDataPools@2021-03-01' = if (createSparkCluster) {
  parent: workspaces
  name: dotnetSparkPoolName
  location: location
  tags: union(defaultTags, customTags)
  properties: {
    nodeCount: int(sparkNodeCount)
    nodeSizeFamily: sparkNodeSizeFamily
    nodeSize: sparkNodeSize
    autoScale: {
      enabled: sparkAutoScaleEnabled
      minNodeCount: sparkMinNodeCount
      maxNodeCount: sparkMaxNodeCount
    }
    autoPause: {
      enabled: sparkAutoPauseEnabled
      delayInMinutes: sparkAutoPauseDelayInMinutes
    }
    sparkVersion: dotnetSparkVersion
    sparkConfigProperties: {
      filename: sparkConfigPropertiesFileName
      content: sparkConfigPropertiesContent
    }
    sessionLevelPackagesEnabled: sessionLevelPackagesEnabled
  }
}

resource diagnosticsettings 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = {
  scope: workspaces
  name: 'diag-${toLower(name)}'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspace)
    logs: [for item in synapseWsDiagLogs: {
      category: item
      enabled: true
    }]
  }
}

resource synapsePrivateEndpoints 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: synapsePrivateEndpointNamesPrimary.primary
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: synapsePrivateEndpointNamesPrimary.primary
        properties: {
          privateLinkServiceId: workspaces.id
          groupIds: [
            'Dev'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(__PRJ-LOWER__Vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', __PRJ-LOWER__Vnet.name, __PRJ-LOWER__Vnet.peSubnet)
    }
    customDnsConfigs: []
  }
}
resource scheduledqueryrules 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: 'Synapse Pipeline Failure ${toLower(name)}'
  location: scheduledqueryrulesLocation
  properties: {
    displayName: 'Synapse Pipeline Failure ${toLower(name)}'
    description: 'Synapse Pipeline Failure ${toLower(name)}'
    severity: 3
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspace)
    ]
    targetResourceTypes: [
      'microsoft.operationalinsights/workspaces'
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'SynapseIntegrationActivityRuns\n| where Status == "Failed" and \n_ResourceId contains "${toLower(name)}"'
          timeAggregation: 'Count'
          dimensions: []
          resourceIdColumn: '_ResourceId'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        resourceId('microsoft.insights/actionGroups', actionGroupsOperationsTeamname)
      ]
    }
  }
}


output privateEndpointDNSRecords array = [
  {
    zone: blobPrivateEndpointDNSZone
    record: defaultDataLakeStorageAccountName
    id: blobprivateEndpoints.id
    resourceGroup: privateDnsResourceGroups.primary
  }
  {
    zone: dfsPrivateEndpointDNSZone
    record: defaultDataLakeStorageAccountName
    id: dfsPrivateEndpoints.id
    resourceGroup: privateDnsResourceGroups.primary
  }
  {
    zone: synapsePrivateEndpointDNSZone
    record: toLower(name)
    id: synapsePrivateEndpoints.id
    resourceGroup: privateDnsResourceGroups.primary
    region: location
  }
]

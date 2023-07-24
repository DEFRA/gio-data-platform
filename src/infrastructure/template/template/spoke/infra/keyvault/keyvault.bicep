param vaultName string
param vaultPrivateEndpointName string
param vaultPrivateEndpointDNSZone string
param vaultPrivateEndpointSubnetID string
param AADTenantID string
param accessPolicies array
param environment string
param createdDate string = utcNow('yyyy-MM-dd')
param customTags object
param __PRJ-LOWER__Network object
param buildAgentIPAddress string
param subnetsCount int
param defaultSecretNames string = ''
param privateDnsResourceGroups object
param location string = resourceGroup().location

var defaultTags = {
  ServiceCode: '__PRJ__'
  ServiceName: '__PRJ__'
  ServiceType: 'SHARED'
  CreatedDate: createdDate
  Environment: environment
  Tier: 'OTHER'
  Location: location
}
var buildAgentIPAddresses = split(buildAgentIPAddress, ';')
var primarySubnetResourceId = '${resourceId(__PRJ-LOWER__Network.primaryRg, 'Microsoft.Network/virtualNetworks', __PRJ-LOWER__Network.primaryVnetName)}/subnets/${__PRJ-LOWER__Network.primarySubnetBaseName}'
var primaryRegionVNetRules = [for i in range(0, subnetsCount): {
  id: '${primarySubnetResourceId}${(1001 + i)}'
}]

resource vaultName_resource 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: vaultName
  location: location
  tags: union(defaultTags, customTags)
  properties: {
    tenantId: AADTenantID
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    accessPolicies: accessPolicies
    enableSoftDelete: true
    // enablePurgeProtection: true TODO: This should be enabled 
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [for item in buildAgentIPAddresses: {
        value: item
      }]
      virtualNetworkRules: primaryRegionVNetRules
    }
  }
}


resource defaultSecrets 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for name in split(defaultSecretNames, ','): {
  name: name
  parent: vaultName_resource
  properties: {
    value: ''
  }
}]


resource vaultPrivateEndpointName_resource 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: vaultPrivateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: vaultPrivateEndpointName
        properties: {
          privateLinkServiceId: vaultName_resource.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: vaultPrivateEndpointSubnetID
      // resourceId(__PRJ-LOWER__Vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', __PRJ-LOWER__Vnet.name, __PRJ-LOWER__Vnet.peSubnet)
    }
    customDnsConfigs: []
  }
}

output privateEndpointDNSRecords array = [
  {
    zone: vaultPrivateEndpointDNSZone
    record: vaultName
    resourceGroup: privateDnsResourceGroups.primary
    id: vaultPrivateEndpointName_resource.id
  }
]

param resourceId string
param keyVaultName string
param envId string
param prj string

resource secrets 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/AzureCosmos-PrimaryKey${prj}${envId}'
  properties: {
    value: listKeys(resourceId, '2015-11-06').primaryMasterKey
  }
}

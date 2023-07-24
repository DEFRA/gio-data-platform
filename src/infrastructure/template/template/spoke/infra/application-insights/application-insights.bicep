param law object
param appInsights object
param environment string
param actionGroupsOperationsTeamname string = 'Operations Team'
param emailReceivers array
param createdDate string = utcNow('yyyy-MM-dd')
param rgLocation string = resourceGroup().location

var defaultTags = { ServiceCode: '__PRJ__', ServiceName: '__PRJ__', ServiceType: 'LOB', CreatedDate: createdDate, Environment: environment, Tier: 'SHARED', Location: rgLocation }

resource workspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: law.name
  location: rgLocation
  tags: union(defaultTags, law.customTags)
  properties: {
    sku: {
      name: law.sku
    }
    retentionInDays: 30
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsights.name
  location: rgLocation
  kind: 'web'
  tags: union(defaultTags, appInsights.customTags)
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: workspace.id
  }
}

resource actionGroups 'microsoft.insights/actionGroups@2021-09-01' = {
  name: actionGroupsOperationsTeamname
  location: 'Global'
  properties: {
    groupShortName: 'Ops Team'
    enabled: true
    emailReceivers: emailReceivers
    smsReceivers: []
    webhookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}


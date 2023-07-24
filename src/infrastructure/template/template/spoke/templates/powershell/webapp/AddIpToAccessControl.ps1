# Example config file
#
# [
#   {
#     "name": "Rule Name",
#     "ip":"1.2.3.4",
#     "priority": 123
#   }
# ]

[CmdletBinding()]
Param
(
  [Parameter(Mandatory = $true)]
  [string]$resourceGroupName,

  [Parameter(Mandatory = $true)]
  [string]$webAppName,

  [Parameter(Mandatory = $true)]
  [string]$configFile
)
[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output "Retrieving existing access control config for '$resourceGroupName/$webAppName'"
$accessRestrictionConfig = Get-AzWebAppAccessRestrictionConfig -ResourceGroupName $resourceGroupName -Name $webAppName

$config = Get-Content $configFile | ConvertFrom-Json

foreach ($ipConfig in $config) {
  if (($ipConfig.name -eq "") -or ($null -eq $ipConfig.name)) {
    Write-Output "Skipping, no name"
    Continue
  }
  if (($ipConfig.ip -eq "") -or ($null -eq $ipConfig.ip)) {
    Write-Output "Skipping, no ip"
    Continue
  }
  if ($ipConfig.ip -notmatch "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}\/\d{1,2}") {
    Write-Error "IP '$($ipConfig.ip)' does not look valid. Does it need '/32' at the end."
    Continue
  }
  
  $existingRuleByIp = $accessRestrictionConfig.MainSiteAccessRestrictions.Where({ $_.IpAddress -eq $ipConfig.ip })[0]
  if ($null -ne $existingRuleByIp) {
    Write-Output "An existing rule already has the ip $($ipConfig.ip)"
    Continue
  }
  
  $existingRuleByName = $accessRestrictionConfig.MainSiteAccessRestrictions.Where({ $_.RuleName -eq $ipConfig.name })[0]
  if ($null -ne $existingRuleByName) {
    Write-Output "Existing rule found, removing..."
    Remove-AzWebAppAccessRestrictionRule -ResourceGroupName $resourceGroupName -WebAppName $webAppName -Name $existingRuleByName.RuleName
  }
  
  Write-Output "Adding access control for $ipConfig"
  Add-AzWebAppAccessRestrictionRule -ResourceGroupName $resourceGroupName -WebAppName $webAppName -Name $ipConfig.name -Priority $ipConfig.priority -Action Allow -IpAddress $ipConfig.ip
}


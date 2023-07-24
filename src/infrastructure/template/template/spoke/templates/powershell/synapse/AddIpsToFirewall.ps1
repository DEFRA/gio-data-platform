# Example config file
#
# [
#   {
#     "name": "Rule Name",
#     "ip":"1.2.3.4"
#   }
# ]

[CmdletBinding()]
Param
(
  [Parameter(Mandatory = $true)]
  [string]$resourceGroupName,

  [Parameter(Mandatory = $true)]
  [string]$workspaceName,

  [Parameter(Mandatory = $true)]
  [string]$configFile
)
[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output "Retrieving existing firewall config for '$resourceGroupName/$workspaceName'"
$firewallConfig = Get-AzSynapseFirewallRule -ResourceGroupName $resourceGroupName -WorkspaceName $workspaceName

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
  $ipConfig.ip = ($ipConfig.ip -split "/" )[0]
  if ($ipConfig.ip -notmatch "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}") {
    Write-Error "IP '$($ipConfig.ip)' does not look valid. It does NOT need '/32' at the end."
    Continue
  }
  
  $existingRuleByIp = $firewallConfig.Where({ $_.StartIpAddress -eq $ipConfig.ip })[0]
  if ($null -ne $existingRuleByIp) {
    Write-Output "An existing rule already has the ip $($ipConfig.ip)"
    Continue
  }
  
  $existingRuleByName = $firewallConfig.Where({ $_.Name -eq $ipConfig.name })[0]
  if ($null -ne $existingRuleByName) {
    Write-Output "Updating existing rule for $ipConfig"
    Update-AzSynapseFirewallRule -ResourceGroupName $resourceGroupName -WorkspaceName $workspaceName -Name $ipConfig.name -StartIpAddress $ipConfig.ip -EndIpAddress $ipConfig.ip
  } else {
    Write-Output "Adding new rule for $ipConfig"
    New-AzSynapseFirewallRule -ResourceGroupName $resourceGroupName -WorkspaceName $workspaceName -Name $ipConfig.name -StartIpAddress $ipConfig.ip -EndIpAddress $ipConfig.ip
  }
}


[CmdletBinding()]
	param(
	   [Parameter(Mandatory=$true)][string]$ResourceGroupName,
       [Parameter(Mandatory=$true)][string]$CosmosAccountName,
       [Parameter(Mandatory=$true)][string]$ConfigurationFilePath
   )

Get-InstalledModule Az.CosmosDb

Write-Output "Retrieving existing access control config for '$ResourceGroupName/$CosmosAccountName'"
$accessRestrictionConfig = (Get-AzCosmosDBAccount -ResourceGroupName $resourceGroupName -Name $CosmosAccountName).IpRules.IpAddressOrRangeProperty

$ips = [System.Collections.ArrayList]::new()
if ($null -ne $accessRestrictionConfig) {
  $ips.AddRange($accessRestrictionConfig)
}

$config = Get-Content $ConfigurationFilePath | ConvertFrom-Json
$newIpAdded = $false

foreach ($ipConfig in $config) {

  if (($ipConfig.name -eq "") -or ($null -eq $ipConfig.name)) {
    Write-Output "Skipping, no name"
    Continue
  }
  if (($ipConfig.ip -eq "") -or ($null -eq $ipConfig.ip)) {
    Write-Output "Skipping, no ip"
    Continue
  }
  if ($ipConfig.ip -notmatch "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}(\/\d{1,2})?") {
    Write-Error "IP '$($ipConfig.ip)' does not look valid."
    Continue
  }
  $existingRuleByIp = $ips.Where({ $_ -eq $ipConfig.ip })[0]
  if ($null -ne $existingRuleByIp) {
    Write-Output "An existing rule already has the ip $($ipConfig.ip)"
    Continue
  }
  
  Write-Output "Adding access control for $ipConfig"
  # Append IP Rules
  $ips.Add($ipConfig.ip)
  $newIpAdded = $true  
}

if($newIpAdded) {
  Write-Output "Updating Cosmos account..." 
  Update-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $CosmosAccountName -IpRule $ips
}



[CmdletBinding()]
	param(
	   [Parameter(Mandatory=$true)][string]$ResourceGroup,
       [Parameter(Mandatory=$true)][string]$KeyVaultName,
       [Parameter(Mandatory=$true)][string]$ConfigurationFilePath
   )

Write-Output "Retrieving existing access control config for '$ResourceGroup/$KeyVaultName'"
$accessRestrictionConfig = Get-AzKeyVault -VaultName $KeyVaultName

$config = Get-Content $ConfigurationFilePath | ConvertFrom-Json


foreach ($ipConfig in $config) {
  if (($ipConfig.name -eq "") -or ($null -eq $ipConfig.name)) {
    Write-Output "Skipping, no name"
    Continue
  }
  if (($ipConfig.ip -eq "") -or ($null -eq $ipConfig.ip)) {
    Write-Output "Skipping, no ip"
    Continue
  }
  #$ipConfig.ip = ($ipConfig.ip -split "/" )[0]
  if ($ipConfig.ip -notmatch "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}(\/\d{1,2})?") {
    Write-Error "IP '$($ipConfig.ip)' does not look valid."
    Continue
  }
  $existingRuleByIp = $accessRestrictionConfig.NetworkAcls.Where({ $_.IpAddressRanges -eq $ipConfig.ip })[0]
  if ($null -ne $existingRuleByIp) {
    Write-Output "An existing rule already has the ip $($ipConfig.ip)"
    Continue
  }
  
  Write-Output "Adding access control for $ipConfig"
  Add-AzKeyVaultNetworkRule -VaultName $KeyVaultName -IpAddressRange "$($ipConfig.ip)"

}


param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1

$jsonFiles = Get-ChildItem -Path $ConfigFilePath -Filter "*.json" -Recurse

$baseUrl = "https://$AccountName.purview.azure.com"

foreach ($file in $jsonFiles) {
  Write-Host $file.FullName
  $config = Get-Content $file.FullName 

  foreach ($collection in $config.collections) 
  {
      foreach ($permission in $collection.permissions) 
      {      
        foreach($permissionGroup in $permission.groupNames)   
        {
          Write-Host "Updating Policy for $permissionGroup"
          $policy = Get-PurviewPolicyByCollectionName -CollectionName $collection.name -ApiVersion '2021-07-01-preview' -BaseUri $baseUrl
         
          #Assign a group to a role
          Add-PurviewPolicyRole  -BaseUri $baseUrl -ApiVersion '2021-07-01-preview' -Policy $policy.values[0] -RoleName $permission.group -GroupId $permissionGroup -CollectionName $collection.name
          Write-Host "Added group with id $permissionGroup to the $permissionGroup role"
        }
      }
  }
}


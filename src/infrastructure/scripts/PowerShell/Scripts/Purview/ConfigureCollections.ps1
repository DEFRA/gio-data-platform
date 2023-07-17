param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath,

    [Parameter(Mandatory = $true)]
    [string]$Environment
)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1

$jsonFiles = Get-ChildItem -Path $ConfigFilePath -Filter "*.json" -Recurse

$baseUrl = "https://$AccountName.purview.azure.com"

$AccessToken = (Get-AzAccessToken -Resource "https://purview.azure.net").Token

foreach ($file in $jsonFiles) {
  Write-Host $file.FullName
  $config = Get-Content $file.FullName 
  $config = $config.Replace("__ENVIRONMENT__", $Environment) | ConvertFrom-Json

  foreach ($collection in $config.Collections) 
  {
      $shortname = [regex]::Replace($collection.Name, "[^a-zA-Z0-9]", "")
      $collectionObject = Get-PurviewCollections -AccessToken $AccessToken -ApiVersion '2019-11-01-preview' -BaseUri $baseUrl
      $targetCollection = $collectionObject.value | Where-Object { $_.friendlyName -eq $collection.ParentCollectionName }

      $existingCollection = $collectionObject.value | Where-Object { $_.friendlyName -eq $collection.Name }

      if ($null -eq $existingCollection)
      {
        Write-Host "Upserting Collection" $collection.Name
       New-PurviewCollection -AccessToken $AccessToken -CollectionName $collection.Name -ApiVersion '2019-11-01-preview' -BaseUri $baseUrl -ParentCollectionName $targetCollection.name
      }
      else {
        $shortname = $existingCollection.name
      }      

      foreach ($permission in $collection.Permissions) 
      {      
        foreach($permissionGroup in $permission.GroupNames)   
        {
          Write-Host "Updating Policy for $permissionGroup"
          #You need to get the policy each time to avoid 409 conflicts as the policy is versioned
          $policy = Get-PurviewPolicyByCollectionName -AccessToken $AccessToken -CollectionName $shortname -ApiVersion '2021-07-01-preview' -BaseUri $baseUrl
          $policyId = $policy.values[0].id
          
          #$groupObjectId = Get-AdGroupObjectId -GroupName $permissionGroup

          #Assign a group to a role
          Add-PurviewPolicyRole -AccessToken $AccessToken -BaseUri $baseUrl -ApiVersion '2021-07-01-preview' -Policy $policy.values[0] -RoleName $permission.Group -GroupId $permissionGroup -CollectionName $shortname
          Write-Host "Added group with id $permissionGroup to the $permissionGroup role"
        }
      }
  }
}


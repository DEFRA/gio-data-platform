param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath,

    [Parameter(Mandatory = $true)]
    [string]$Environment
)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1
#Import-Module $PSScriptRoot/../Modules/ActiveDirectory/UsersAndGroups/ADGroups.psm1

$jsonFiles = Get-ChildItem -Path $ConfigFilePath -Filter "*.json" -Recurse

#$item = $group = Get-AzureADGroup -Filter "displayName eq 'AG-Azure-UKB-DEV-Purview-RootCollectionAdmin'"
#Write-Host "ObjectId is" $item.ObjectId

$baseUrl = "https://$AccountName.purview.azure.com"

$AccessToken = (Get-AzAccessToken -Resource "https://purview.azure.net").Token

#$groupName='Group'

#$headers = @{
#    'Authorization' = "Bearer $AccessToken"
#    'Content-Type' = 'application/json'
#}

# Make the GET request to retrieve the group
#$uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'"
#$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Check the response status
#if ($response.StatusCode -eq 200) {
#    $groupData = $response | ConvertFrom-Json#

#    # Process the retrieved group data as needed
#   if ($groupData.value.Count -gt 0) {
#        $group = $groupData.value[0]
#        Write-Host "Group name: $($group.displayName)"
#        Write-Host "Group ID: $($group.id)"
#    }
#    else {
#        Write-Host "Group not found."
#    }
#}
#else {
#    Write-Host "Request failed with status code $($response.StatusCode): $($response | ConvertTo-Json -Depth 3)"
#}

foreach ($file in $jsonFiles) {
  Write-Host $file.FullName
  $config = Get-Content $file.FullName 
  $config = $config.Replace("__ENVIRONMENT__", $Environment) | ConvertFrom-Json

  foreach ($collection in $config.Collections) 
  {
      $shortname = $collection.Name.Replace(" ", "")
      $collectionObject = Get-PurviewCollections -AccessToken $AccessToken -ApiVersion '2019-11-01-preview' -BaseUri $baseUrl
      $targetCollection = $collectionObject.value | Where-Object { $_.friendlyName -eq $collection.ParentCollectionName }

      Write-Host "Upserting Collection" $collection.Name
      New-PurviewCollection -AccessToken $AccessToken -CollectionName $collection.Name -ApiVersion '2019-11-01-preview' -BaseUri $baseUrl -ParentCollectionName $targetCollection.name

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


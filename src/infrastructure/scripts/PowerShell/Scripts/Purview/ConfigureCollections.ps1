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

$AccessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Ii1LSTNROW5OUjdiUm9meG1lWm9YcWJIWkdldyIsImtpZCI6Ii1LSTNROW5OUjdiUm9meG1lWm9YcWJIWkdldyJ9.eyJhdWQiOiI3M2MyOTQ5ZS1kYTJkLTQ1N2EtOTYwNy1mY2M2NjUxOTg5NjciLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC9jOWQ3NDA5MC1iNGU2LTRiMDQtOTgxZC1lNjc1N2ExNjA4MTIvIiwiaWF0IjoxNjg5NTg2NDIwLCJuYmYiOjE2ODk1ODY0MjAsImV4cCI6MTY4OTU5MDc4OSwiYWNyIjoiMSIsImFpbyI6IkFXUUFtLzhUQUFBQTlyMmRha2hHTU15cmVmcnFIWGVlaVFxbHRncHpiTGJoSk1seW9qa0NDS1IwU3ZpSVc3ZktPVHdsWWNiMUEyNHhPUTJRb3NadmRVc2dNM20vNE5MTmQ2Zms2a3ZUT0ZvTkhoTStQc3dySU5mbmhKcVZxTWZCRXZVaXZ4cWZRUjVXIiwiYWx0c2VjaWQiOiI1OjoxMDAzMjAwMEJENjlERjExIiwiYW1yIjpbInB3ZCIsIm1mYSJdLCJhcHBpZCI6IjYzMmQ4MDNhLWIwYzItNDliNC1hOTQ0LWUxM2MzODRjMDRhOCIsImFwcGlkYWNyIjoiMCIsImVtYWlsIjoiYS1tYXJrLmN1bm5pbmdoYW1AZGVmcmEub25taWNyb3NvZnQuY29tIiwiaWRwIjoiaHR0cHM6Ly9zdHMud2luZG93cy5uZXQvNzcwYTI0NTAtMDIyNy00YzYyLTkwYzctNGUzODUzN2YxMTAyLyIsImlwYWRkciI6Ijg2LjE1Ni4xMTAuMjMwIiwibmFtZSI6Ik1hcmsgQ3VubmluZ2hhbSIsIm9pZCI6IjNiYjllZWEyLWNiNDItNDI5Mi1iZGQ1LWJiOTllNzRmZDM5ZSIsInB1aWQiOiIxMDAzMjAwMEZBQzc1MjczIiwicmgiOiIwLkFVY0FrRURYeWVhMEJFdVlIZVoxZWhZSUVwNlV3bk10Mm5wRmxnZjh4bVVaaVdkSEFOQS4iLCJzY3AiOiJkZWZhdWx0Iiwic3ViIjoiQS1RZm11azZUYXh1SEs5LWhqMFowNy1LcmFQeEVUcFdtbTRqWER6SEFQbyIsInRpZCI6ImM5ZDc0MDkwLWI0ZTYtNGIwNC05ODFkLWU2NzU3YTE2MDgxMiIsInVuaXF1ZV9uYW1lIjoiYS1tYXJrLmN1bm5pbmdoYW1AZGVmcmEub25taWNyb3NvZnQuY29tIiwidXRpIjoiY05meWkwejJwVVNPYlhYSDduSVlBQSIsInZlciI6IjEuMCJ9.DjNVOEgV4BDg-D5Lol-AYdtVsc3WB59EHxyPnrdhM2T3yHSNcFXjtvzjfqV4RRp5AyfyNiZwwL8_-BFBGmYazK6wZudMGiwiI7WU5qMdPI01GyH7MrLqODttfcrRyT-jst7opDcr2nCc3uh32DalD4poWAoPaM0rV1U3yXyxhzO4X2vtTdFK2kgV_dqWfUH9fjW5afSKFmtIgKyU62KoyxgDN70TGhJH-mcLUL5MF0c9QauEcmzZUXIitgOLyZaDiCQGfx325-nueZhd4wuo7Qcd3uvl4lL2DtGq54GgUdh0x_WunL4wTHW9w0oeSiSDMxY10ETLv7HQSDrVRs59VA" #(Get-AzAccessToken -Resource "https://purview.azure.net").Token

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


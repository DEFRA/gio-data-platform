param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1
$jsonFiles = Get-ChildItem -Path $ConfigFilePath -Filter "*.json" -Recurse

$baseUrl = "https://$AccountName.purview.azure.com"

foreach ($file in $jsonFiles) 
{
  Write-Host $file.FullName
  $config = Get-Content $file.FullName | ConvertFrom-Json
    
  foreach ($classification in $config.classificationDefs) 
  {   
        $items = @{
          classificationDefs = @($classification)
        }       
        try
        {
          Write-Host "Attempting to Update the Classification"
          Update-TypeDefinitions -BaseUri $baseUrl -templateDefinition $items -Verb "PUT"
        }
        catch
        {
          Write-Host "Failing to Update the Classification, Error Details:"
          Write-Host "Error Message: $($_.ErrorDetails.Message)"
          Write-Host "Error Category Info: $($_.CategoryInfo.ToString())"
          Write-Host "Error Id: $($_.FullyQualifiedErrorId)"
          Write-Host "Error PositionMessage: $($_.InvocationInfo.PositionMessage)"

          Write-Host "Attempting to create the Classification"
          Update-TypeDefinitions -BaseUri $baseUrl -templateDefinition $items -Verb "POST"
        }         
    }
}
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

  $config = Get-Content $file.FullName  | ConvertFrom-Json

  Set-TermTemplate -BaseUri $baseUrl -templateDefinition $config      

}

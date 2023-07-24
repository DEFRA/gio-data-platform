[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$containerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$apiName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$webAppName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$apiVersion,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$keyVaultName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientType
)
[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. $PSScriptRoot\..\CommonFunctions.ps1

$authorization = Get-AadTokenForWebApp -WebAppName $webAppName -ClientIdKey "AdoSpClientId" -ClientSecretKey "AdoSpClientSecret" -KeyVaultName $keyVaultName -Tenantid $tenantId

Write-Host "Reading Swagger for: $webAppName"
$swaggerJsonUrl = "https://$webAppName.azurewebsites.net/swagger/$apiVersion/swagger.json"
$apiSpecResponse = Invoke-WebRequest -Uri $swaggerJsonUrl -UseBasicParsing -Headers @{"Authorization" = $authorization}

$options = @"
{ "packageName": "$apiName" }
"@

if ($clientType -eq 'java') {
    $nameParts = $apiName.Split('.');
    
    $options = @"
{
    "artifactId": "$apiName",
    "artifactUrl": "",
    "artifactVersion": "$Env:packageVersion",
    "groupId": "Defra",
    "developerEmail": "",
    "developerName": "Defra __PRJ__ API Team",
    "artifactDescription": "Defra __PRJ__ client library for $($nameParts[$nameParts.Length - 3]) API.",
    "dateLibrary": "joda",
    "invokerPackage": "$apiName",
    "modelPackage": "$($apiName).model",
    "apiPackage": "$($apiName).api"
}
"@
}

$json = @"
{
    "options": $options,
    "spec": $($apiSpecResponse.Content)
}
"@

$destinationFolder = $Env:BUILD_SOURCESDIRECTORY
$instance = Get-AzResource -ResourceType Microsoft.ContainerInstance/containerGroups | Where-Object { $_.Name -eq $containerName }
$container = Get-AzContainerGroup -ResourceGroupName $instance.ResourceGroupName -Name $containerName


$jsonEncoded = [Text.Encoding]::UTF8.GetString(
    [Text.Encoding]::GetEncoding(28591).GetBytes($json)
  )

Write-Host "POST Request to generate API client..."
$codeGenResponse = Invoke-WebRequest -Method Post -ContentType "application/json" -Uri "http://$($container.IpAddress):8080/api/gen/clients/$clientType" -Body $jsonEncoded -UseBasicParsing
if ($null -ne $codeGenResponse) {
    $response = $codeGenResponse.Content | ConvertFrom-Json

    if ($null -ne $response) {
        Write-Host "Downloading generated client..."
        Invoke-WebRequest -Uri $response.link -OutFile "$destinationFolder\$apiName.zip" -UseBasicParsing

        Write-Host "Extracting client library files..."
        Expand-Archive -Path "$destinationFolder\$apiName.zip" -DestinationPath $destinationFolder\$apiName
    }
}
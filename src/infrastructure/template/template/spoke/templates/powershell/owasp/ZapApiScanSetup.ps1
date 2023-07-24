[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$adoClientId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$adoClientSecret,

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
    [string]$subscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$testServerUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Int", "Ext")]
    [string]$apiType,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("dev", "tst")]
    [string]$environment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$defraGovUKApplicationDomain
    
)
[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. $PSScriptRoot\..\CommonFunctions.ps1

Connect-UsingSP -userName $adoClientId -pwd $adoClientSecret -tenantId $tenantId -subscriptionId $subscriptionId

$authorization = Get-AadTokenForWebApp -WebAppName $webAppName -ClientIdKey "AdoSpClientId" -ClientSecretKey "AdoSpClientSecret" -KeyVaultName $keyVaultName -Tenantid $tenantId

Write-Host "Reading Swagger for: $webAppName"
$swaggerJsonUrl = "https://$webAppName.azurewebsites.net/swagger/$apiVersion/swagger.json"
$apiSpecResponse = Invoke-WebRequest -Uri $swaggerJsonUrl -Headers @{"Authorization" = $authorization} -UseBasicParsing

Write-Host "Updating Swagger with additional properties.."
$serverUrl = @(@{ url= "$testServerUrl" })
$json = $apiSpecResponse.Content | ConvertFrom-Json -AsHashtable
$json | Add-Member -Name "servers" -value $serverUrl -MemberType NoteProperty

$authHeader = @{
    "name"="Authorization"
    "required"= "true"
    "in" = "header"
    "schema" = @{
        "type" = "string"
        "default" = "Abc"
    }
}

$subHeader = @{
    "name"="Ocp-Apim-Subscription-Key"
    "required"= "true"
    "in" = "header"
    "schema" = @{
        "type" = "string"
        "default" = "123"
    }
}

foreach($path in $json.paths.Keys) {
    foreach($operation in $json.paths.$path.Keys) {
        $json.paths.$path.$operation.parameters += $authHeader
        $json.paths.$path.$operation.parameters += $subHeader
    }
}

$json | ConvertTo-Json -depth 100 -Compress | Out-File "$webAppName.json" -Encoding utf8

Write-Host "Building Options..."
if ($apiType -eq 'Int') { $subKey = "ApimInternalClientsSubscription" } elseif ($apiType -eq 'Ext') { $subKey = "ApimInternalClientsSubscriptionExternal" }
$subscriptionKey = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $subKey

$clientId = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "DevPortal-ClientId-$apiType"
$clientIdSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "DevPortal-ClientSecret-$apiType"
$resouceId = "api://$environment-future__PRJ__-$($apiType.ToLower()).$defraGovUKApplicationDomain/.default"
$aadToken = Get-AadToken -ClientId $clientId.SecretValueText -ClientSecret $clientIdSecret.SecretValue -ResouceId $resouceId -Tenantid $Tenantid

$optionsContent = Get-Content -path $PSScriptRoot\options.prop
$optionsContent = $optionsContent -replace '#{{ AUTH_TOKEN }}', $aadToken.access_token
$optionsContent = $optionsContent -replace '#{{ SUB_KEY }}', $subscriptionKey.SecretValueText

$shareFolderName = "$webAppName-$($Env:BUILD_BUILDID)"
$zapOptions = "zap-api-scan.py -t $shareFolderName/$WebAppName.json -f openapi -r $shareFolderName/$WebAppName.html -x $shareFolderName/$WebAppName.xml -z '"
foreach($line in $optionsContent) {
    $zapOptions += "-config $line "
}
$zapOptions = $zapOptions.Substring(0, $zapOptions.Length-1)
$zapOptions += "' -d"
Write-Host "##vso[task.setvariable variable=ZapOptions;]$zapOptions"

$accountDetails = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts | Where-Object { $_.Name -eq $storageAccountName }
$storageAccount = Get-AzStorageAccount -ResourceGroupName $accountDetails.ResourceGroupName -Name $storageAccountName
$share = Get-AzStorageShare -Name owaspresults -Context $storageAccount.Context

Write-Host "Uploading files to storage account..."
New-AzStorageDirectory -Share $share -Path "$shareFolderName"
Set-AzStorageFileContent -Share $share -Path "$shareFolderName" -Source "$webAppName.json" -Force
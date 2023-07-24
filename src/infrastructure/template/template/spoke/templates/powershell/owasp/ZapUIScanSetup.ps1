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
    [string]$filePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$fileName
)

[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. $PSScriptRoot\..\CommonFunctions.ps1

Connect-UsingSP -userName $adoClientId -pwd $adoClientSecret -tenantId $tenantId -subscriptionId $subscriptionId

$zapOptions = "zap-baseline.py -t $testServerUrl -r $filePath/$fileName.html -x $filePath/$fileName.xml --autooff -d"
Write-Host "##vso[task.setvariable variable=zapOptions;]$zapOptions"

$accountDetails = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts | Where-Object { $_.Name -eq $storageAccountName }
$storageAccount = Get-AzStorageAccount -ResourceGroupName $accountDetails.ResourceGroupName -Name $storageAccountName
$share = Get-AzStorageShare -Name owaspresults -Context $storageAccount.Context

Write-Host "Create scan results folder in storage account..."
New-AzStorageDirectory -Share $share -Path "$filePath"
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$fileShareName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$filePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$fileName,

    [Parameter(Mandatory = $false)]
    [string]$destinationPath = $Env:BUILD_ARTIFACTSTAGINGDIRECTORY,

    [Parameter(Mandatory = $false)]
    [string]$destinationFileName
)

$accountDetails = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts | Where-Object { $_.Name -eq $storageAccountName }
$storageAccount = Get-AzStorageAccount -ResourceGroupName $accountDetails.ResourceGroupName -Name $storageAccountName

Write-Host "Downloading report from storage account... $filePath/$fileName"
$destinationPath = $Env:BUILD_ARTIFACTSTAGINGDIRECTORY
$destinationFileName = "\$destinationFileName"
Get-AzStorageFileContent -ShareName $fileShareName -Context $storageAccount.Context -Path "$filePath/$fileName" -Destination "$destinationPath$destinationFileName" -Force

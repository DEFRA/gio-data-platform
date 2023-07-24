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
    [string]$tenantId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$subscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$shareName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$shareFolderName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$fullFileName,

    [Parameter(Mandatory = $false)]
    [string]$extraArgs
)

function RemoveFileDir ([Microsoft.Azure.Storage.File.CloudFileDirectory] $dir)
{   
    $filelist = Get-AzStorageFile -Directory $dir
    foreach ($f in $filelist)
    {   
        if ($f.GetType().Name -eq "CloudFileDirectory")
        {
            RemoveFileDir $f #recursion
        }
        else
        {
            Remove-AzStorageFile -File $f           
        }
    }
    Remove-AzStorageDirectory -Directory $dir
}

[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. $PSScriptRoot\..\CommonFunctions.ps1

Connect-UsingSP -userName $adoClientId -pwd $adoClientSecret -tenantId $tenantId -subscriptionId $subscriptionId

$fileParts = ($fullFileName).split('/')
$fileName = $fileParts[$fileParts.Length - 1]
$filePath = ($fileParts -join '/').Replace("$fileName", '')

if($extraArgs -eq "")
{
    $bztOptions = "bzt /bzt-configs/$shareFolderName/$fileName -report -o reporting.2.filename=$shareFolderName/report/reportTests.xml"
    Write-Host "no extraArgs $extraArgs"
}
else{
    $bztOptions = "bzt /bzt-configs/$shareFolderName/$fileName -report -o $extraArgs -o reporting.2.filename=$shareFolderName/report/reportTests.xml"
    Write-Host "extraArgs $extraArgs"
}
Write-Host "##vso[task.setvariable variable=bztOptions;]$bztOptions"
Write-Host "$bztOptions"

$accountDetails = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts | Where-Object { $_.Name -eq $storageAccountName }
$storageAccount = Get-AzStorageAccount -ResourceGroupName $accountDetails.ResourceGroupName -Name $storageAccountName
$share = Get-AzStorageShare -Name $shareName -Context $storageAccount.Context

Write-Host "Uploading files to storage account..."

$folder = Get-AzStorageFile -Share $share -Path "$shareFolderName" -ErrorAction SilentlyContinue
if($folder.Name -notcontains $shareFolderName){
    Write-Host "creating folder '$shareFolderName'"
}
else{
    Write-Host "deleting exising folder"    
    RemoveFileDir $folder
}
New-AzStorageDirectory -Share $share -Path "$shareFolderName"

Get-ChildItem -Recurse -File "$($Env:BUILD_SOURCESDIRECTORY)/$($Env:BUILD_REPOSITORY_NAME)/$filePath" | 
Foreach-Object {
    $path = $_.FullName
    Set-AzStorageFileContent -Share $share -Path "$shareFolderName" -Source "$path" -Force

}



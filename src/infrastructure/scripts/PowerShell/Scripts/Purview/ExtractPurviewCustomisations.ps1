param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [Parameter(Mandatory = $true)]
    [string]$ExportSettings,
    
    [Parameter(Mandatory = $true)]
    [string]$AdoAccessToken,

    [Parameter(Mandatory = $true)]
    [string]$SourceBranch,
    
    [Parameter(Mandatory = $true)]
    [string]$QueuedBy,

    [Parameter(Mandatory = $true)]
    [string]$RootRepoPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetRepoUrl


)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1

$exportConfig = Get-Content $ExportSettings | ConvertFrom-Json

$baseUrl = "https://$AccountName.purview.azure.com"
$AccessToken = (Get-AzAccessToken -Resource "https://purview.azure.net").Token

#Collections
$collections = Get-PurviewCollections -AccessToken $AccessToken -BaseUri $baseUrl -ApiVersion 2019-11-01-preview 

Write-Host "Retrieved $($collections.value.Length) Collections"

if($true -ne $exportConfig.IncludeRootCollection)
{
    $collections.value = $collections.value[1..($collections.value.Length - 1)]
}

if($true -ne $exportConfig.IgnoreSystemGeneratedFieldsOnImport)
{
    foreach ($obj in $collections.value) {
        $obj.PSObject.Properties.Remove("systemData")
        $obj.PSObject.Properties.Remove("collectionProvisioningState")
    }
}

Out-FileWithDirectory -FilePath $FolderPath\Collections\collections.json -Encoding UTF8 -Content $collections.value -ConvertToJson

Set-Location -Path $RootRepoPath

$repoName = $SourceBranch.Replace("refs/heads/","")

git checkout -b $repoName

git config --global user.email "QueuedBy"
git config --global user.name "$QueuedBy"
git add --all
git commit -m "Updates"
git -c http.extraheader="AUTHORIZATION: bearer $($AdoAccessToken)" push origin
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
    [string]$TargetRepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$AdoProject,

    [Parameter(Mandatory = $true)]
    [string]$AdoAccountUrl

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

$branch = $SourceBranch.Replace("refs/heads/","")

git checkout -b $branch

git config --global user.email "QueuedBy"
git config --global user.name "$QueuedBy"
git add --all
git commit -m "Updates"
git -c http.extraheader="AUTHORIZATION: bearer $($AdoAccessToken)" push origin --set-upstream $branch

#ADO Create a PR Automatically


$env:AZURE_DEVOPS_EXT_PAT = $AdoAccessToken

az repos pr create --auto-complete true --bypass-policy false --delete-source-branch true --description 'Extracted latest Changes from Purview' ----source-branch $branch --squash true --target-branch main --title "PR for Purview Config" --project $AdoProject --org $AdoAccountUrl

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

#Set working directory
Set-Location -Path "$RootRepoPath"

git -c http.extraheader="AUTHORIZATION: bearer $($AdoAccessToken)"

git clone $TargetRepoUrl

Out-FileWithDirectory -FilePath $FolderPath\Collections\collections.json -Encoding UTF8 -Content $collections.value -ConvertToJson

#Glossaries

Write-Host "Extracting into $($SourceBranch) under folder $($FolderPath)"


#Git Commit


$branchName = $SourceBranch.Replace("refs/heads/","")

git checkout -b $branchName


# Configure user details
git config --global user.email "$QueuedBy"
git config --global user.name "$QueuedBy"

# Add changes and commit
git add --all
git commit -m "Add Purview extraction files to $branchName branch"

# Push to the specific branch
git push origin $branchName

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
    [string]$RootRepoPath

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

#Glossaries

Write-Host "Extracting into $($SourceBranch) under folder $($FolderPath)"


#Git Commit
Set-Location -Path "$RootRepoPath"

$repoName = $SourceBranch.Replace("refs/heads/","")


# Fetch changes before switching branches
git fetch

# Checkout the branch explicitly, creating it if necessary
git checkout -B $repoName origin/$repoName

# Configure user details
git config --global user.email "$QueuedBy"
git config --global user.name "$QueuedBy"

# Add changes and commit
git add --all
git commit -m "Add Purview extraction files to $repoName branch"

# Push to the specific branch
git -c http.extraheader="AUTHORIZATION: bearer $($AdoAccessToken)" push origin $repoName

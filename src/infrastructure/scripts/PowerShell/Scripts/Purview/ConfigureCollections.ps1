param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath,

    [Parameter(Mandatory = $true)]
    [string]$ImportConfigPath
)

$baseUrl = "https://$AccountName.purview.azure.com"

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1

$importConfig =   Get-Content -Path $ImportConfigPath | ConvertFrom-Json 
$config = Get-Content -Path $ConfigFilePath 

#Replace Extracted Token
foreach($token in $importConfig.tokens)
{
    if ($token.tokenName -eq "accountName")
    {
        $config = $config.Replace($token.tokenValue.ToLower(), $AccountName.ToLower())
        Write-Host "Replaced Tokens in extract files"
    }
}

$config = $config | ConvertFrom-Json

Write-Host $config

foreach ($collection in $config) 
{
    Set-Collection -Collection $collection -ApiVersion 2019-11-01-preview -BaseUri $baseUrl
}

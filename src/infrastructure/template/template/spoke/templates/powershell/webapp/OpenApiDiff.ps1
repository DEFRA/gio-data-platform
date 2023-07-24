param(
    [Parameter(Mandatory)][string]$TenantID,
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$AppResourceGroup,
    [Parameter(Mandatory)][string]$ClientID,
    [Parameter(Mandatory)][string]$ClientSecret,
    [Parameter(Mandatory)][string]$VaultName,
    [Parameter()][string]$AllowBreakingChanges = 'false'
)

$ErrorActionPreference = 'Stop'

Import-Module $PSScriptRoot\..\CommonFunctions.ps1

$AllowBreakingChangesBool = [System.Convert]::ToBoolean($AllowBreakingChanges)

Function Get-SwaggerDefinition {

    param(
        [Parameter(Mandatory)][string]$TenantID,
        [Parameter(Mandatory)][string]$AppName,
        [Parameter(Mandatory)][string]$ClientID,
        [Parameter(Mandatory)][string]$ClientSecret,
        [Parameter(Mandatory)][string]$OAuthID,
        [Parameter(Mandatory)][string]$OutFile
    )

    $auth_body = @{
        grant_type = 'client_credentials'
        scope = "$OAuthID/.default"
        client_id = $ClientID
        client_secret = $ClientSecret
    }
    $auth = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method Post -Body $auth_body

    $req_header = @{
        Authorization = '{0} {1}' -f ($auth.token_type , $auth.access_token)
    }

    $req = Invoke-WebRequest "https://$AppName.azurewebsites.net/swagger/v1/swagger.json" -Headers $req_header -UseBasicParsing -ContentType  'application/json; charset=utf-8'

    $req.Content | Out-File -FilePath $OutFile -Encoding utf8

}

# Create relative temp path (required, as openapi-diff is incompatible with full Windows paths)
New-Item -Path '.\_temp' -Type Directory -Force | Out-Null

# Get swagger definition
$server_farm_name = (Get-AzWebApp $AppName -ResourceGroupName $AppResourceGroup).ServerFarmId -replace '.*/'
$oauthid_var = "$($server_farm_name -replace '^.{3}')-OAuth-ClientID"
$oauth_id = Get-KVSecret -VaultName $VaultName -SecretName $oauthid_var
Get-SwaggerDefinition -TenantID $TenantID -AppName $AppName -ClientID $ClientID -ClientSecret $ClientSecret -OAuthID $oauth_id -OutFile './_temp/swagger.json'

# Get TST swagger definition

Try {
    $AppName_tst = $AppName -replace '^.{3}', 'tst'
    $oauthid_var_tst = "$oauthid_var-TST"
    $oauth_id_tst = Get-KVSecret -VaultName $VaultName -SecretName $oauthid_var_tst
    Get-SwaggerDefinition -TenantID $TenantID -AppName $AppName_tst -ClientID $ClientID -ClientSecret $ClientSecret -OAuthID $oauth_id_tst -OutFile './_temp/swagger-tst.json'
} Catch {
    If ($AllowBreakingChangesBool) {
        Write-Host '##vso[task.logissue type=warning]Could not retrieve TST OpenAPI definition, but AllowBreakingChanges is set to true.'
        Exit 0
    } Else {
        $_
        Exit 1
    }
}

$env:npm_config_loglevel='silent'
& npm init -y
& npm install openapi-diff

$diff = & './node_modules/.bin/openapi-diff.cmd' './_temp/swagger.json' './_temp/swagger-tst.json'
'./_temp/swagger.json', './_temp/swagger-tst.json' | Remove-Item -Force

$diff_obj = $diff[1..($diff.Length-1)] | ConvertFrom-Json

If ($diff_obj.nonBreakingDifferences) {
    Write-Host "Non-Breaking differences: ----------"
    Write-Host ($diff_obj.nonBreakingDifferences | ConvertTo-Json -Depth 100)
    Write-Host "------------------------------------"
    Write-Host '##vso[task.logissue type=warning]Non-breaking differences detected. Review openapi-diff output'
}

If ($diff_obj.unclassifiedDifferences) {
    Write-Host "Unclassified differences: ----------"
    Write-Host ($diff_obj.unclassifiedDifferences | ConvertTo-Json -Depth 100)
    Write-Host "------------------------------------"
    Write-Host '##vso[task.logissue type=warning]Unclassified differences detected. Review openapi-diff output'
}

If ($diff_obj.breakingDifferences) {
    Write-Host "Breaking differences: --------------"
    Write-Host ($diff_obj.breakingDifferences | ConvertTo-Json -Depth 100)
    Write-Host "------------------------------------"
    If ($AllowBreakingChangesBool) {
        Write-Host '##vso[task.logissue type=warning]Breaking differences detected. Review openapi-diff output'
    } Else {
        Write-Host '##vso[task.logissue type=error]Breaking differences detected. Review openapi-diff output'
        Exit 1
    }
}

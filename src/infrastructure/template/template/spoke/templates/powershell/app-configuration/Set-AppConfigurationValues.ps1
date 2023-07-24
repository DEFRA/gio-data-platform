param(
    [Parameter(Mandatory)][string]$configurationServiceUri,
    [Parameter(Mandatory)][string]$configPath
)

$settings = Get-Content $configPath | ConvertFrom-Json

foreach ($setting in $settings) {
    Write-Output "Adding setting: $($setting.key)"

    if ($setting.value) {
        $contentType = " "
        if ($setting.contentType) { $contentType = $setting.contentType }

        if ($setting.label) {
            az appconfig kv set --endpoint=$configurationServiceUri --auth-mode login --key $setting.key --value "$($setting.value)" --content-type "$contentType" --label "$($setting.label)" --yes | Out-Null
        }
        else {
            az appconfig kv set --endpoint=$configurationServiceUri --auth-mode login --key $setting.key --value "$($setting.value)" --content-type "$contentType" --yes | Out-Null    
        }
    }
    elseif ($setting.secretIdentifier) {
        if ($setting.label) {
            az appconfig kv set-keyvault --endpoint=$configurationServiceUri --auth-mode login --key $setting.key --secret-identifier $setting.secretIdentifier --label "$($setting.label)" --yes | Out-Null
        }
        else {
            az appconfig kv set-keyvault --endpoint=$configurationServiceUri --auth-mode login --key $setting.key --secret-identifier $setting.secretIdentifier --yes | Out-Null
        }
    }
}
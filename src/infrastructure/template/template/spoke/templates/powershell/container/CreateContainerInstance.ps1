[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$containerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$imageName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$vNetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$vNetResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$subnetName,

    [Parameter(Mandatory = $false)]
    [string]$ports = 8080,

    [Parameter(Mandatory = $false)]
    [string]$storageAccount,

    [Parameter(Mandatory = $false)]
    [string]$shareName,

    [Parameter(Mandatory = $false)]
    [string]$mountPath = '/zap/wrk/',

    [Parameter(Mandatory = $false)]
    [string]$options,

    [Parameter(Mandatory = $false)]
    [string]$acrName,

    [Parameter(Mandatory = $false)]
    [string]$keyVaultName_acr
)

Write-Host "Reading VNet Details..."
$vnet = (az network vnet show -n $vNetName --resource-group $vNetResourceGroup) | ConvertFrom-Json
$acrLoginServer = "$acrName.azurecr.io"

if ($storageAccount -ne '') {
    Write-Host "Reading Storage Account Key..."
    $storageKey = az storage account keys list -g $resourceGroupName --account-name $storageAccount --query "[0].value"

    Write-Host "Creating Container Instance..."
    if($acrName -ne '')
    {
        az container create --command-line "tail -f /dev/null" -g $resourceGroupName -n $containerName --image $imageName --vnet $vnet.id --subnet $subnetName --ports $ports --azure-file-volume-account-name $storageAccount --azure-file-volume-account-key $storageKey --azure-file-volume-share-name $shareName --azure-file-volume-mount-path $mountPath --command-line $options --restart-policy Never --cpu 2 --memory 16 --registry-login-server $acrLoginServer --registry-username $(az keyvault secret show --vault-name $keyVaultName_acr -n AdoSpClientId --query value -o tsv) --registry-password $(az keyvault secret show --vault-name $keyVaultName_acr -n AdoSpClientSecret --query value -o tsv)
    }
    else{
        az container create -g $resourceGroupName -n $containerName --image $imageName --vnet $vnet.id --subnet $subnetName --ports $ports --azure-file-volume-account-name $storageAccount --azure-file-volume-account-key $storageKey --azure-file-volume-share-name $shareName --azure-file-volume-mount-path $mountPath --command-line $options --restart-policy Never --cpu 2 --memory 16
    }
}
else {
    Write-Host "Creating Container Instance..."
    if($acrName -ne '')
    {
        az container create --command-line "tail -f /dev/null" -g $resourceGroupName -n $containerName --image $imageName --vnet $vnet.id --subnet $subnetName --ports $ports --azure-file-volume-account-name $storageAccount --azure-file-volume-account-key $storageKey --azure-file-volume-share-name $shareName --azure-file-volume-mount-path $mountPath --command-line $options --restart-policy Never --cpu 2 --memory 16 --registry-login-server $acrLoginServer --registry-username $(az keyvault secret show --vault-name $keyVaultName_acr -n AdoSpClientId --query value -o tsv) --registry-password $(az keyvault secret show --vault-name $keyVaultName_acr -n AdoSpClientSecret --query value -o tsv)
    }
    else{
        az container create -g $resourceGroupName -n $containerName --image $imageName --ports $ports --vnet "$($vnet.id)" --subnet $subnetName --cpu 2 --memory 16
    }
}

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$containerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $false)]
    [bool]$force = $false
)

if ($force) {
    Write-Host "Stopping Container Instance..."
    az container stop --name $containerName --resource-group $resourceGroupName
}

do {
    Start-Sleep -Seconds 50
    write-host "Running scan..."

    $currentState = $(az container show --resource-group $resourceGroupName --name $containerName --query containers[].instanceView.currentState.state --output tsv)
    write-host "Current state:" + $currentState
    if ($currentState -ne "Running")
    {
        break
    }
} until ($currentState -ne "Running")

Write-Host "Deleting Container Instance..."
az container delete --name $containerName --resource-group $resourceGroupName --yes

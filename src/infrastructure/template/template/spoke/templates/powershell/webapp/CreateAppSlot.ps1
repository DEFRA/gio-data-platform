[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$appName,

    [Parameter(Mandatory = $true)]
    [string]$slotName
)

Write-Output "Creating App Deployment Slot if not exists for Slot name: $slotName"
$slotDetails = Get-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $appName -Slot $slotName -ErrorAction SilentlyContinue
if ($null -eq $slotDetails) {
    Write-Output "Slot does not exist. Creating slot.... $slotName"

    New-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $appName -Slot $slotName
    Set-AzWebAppSlot -AssignIdentity $true -HttpsOnly $true -ResourceGroupName $resourceGroupName -Name $appName -Slot $slotName

    Write-Output "Slot created and MI assigned with HTTPS only."
}

Write-Output "Starting deployment slot..."
Start-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $appName -Slot $slotName
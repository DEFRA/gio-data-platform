param(
    [Parameter(Mandatory=$true)][string]$SynapseWorkspaceName,
    [Parameter(Mandatory=$true)][string]$PrivateLinkName,
    [Parameter(Mandatory=$true)][string]$PrivateLinkResourceId,
    [Parameter(Mandatory=$true)][string]$PrivateLinkGroup
 )

[Net.ServicepointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

Import-Module "$PSScriptRoot\modules\SynapseRestAPI.psm1" -force 
Install-Module -Name Az.Network -Scope CurrentUser -Force -AllowClobber -RequiredVersion 4.20.0
Import-Module Az.Network

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token

$privLinkSynapse = New-SynapseManagedPrivateLink `
                -AuthToken $token -WorkspaceName $SynapseWorkspaceName -PrivateLinkName $PrivateLinkName `
                -PrivateLinkResourceId $PrivateLinkResourceId -PrivateLinkGroup $PrivateLinkGroup

$cnt = 120
while (($privLinkSynapse.properties.provisioningState -eq "Provisioning") -and ($cnt -gt 0)) {
    Write-Debug "Waiting 5s for Synapse to finish link provisioning ..."
    $cnt--
    Start-Sleep -Seconds 5
    $privLinkSynapse = Get-SynapseManagedPrivateLink `
                -AuthToken $token -WorkspaceName $SynapseWorkspaceName -PrivateLinkName $PrivateLinkName
}

if ($cnt -gt 0) {
    $privLink = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $PrivateLinkResourceId | Where-Object { $_.PrivateEndpoint.Id -like "*$SynapseWorkspaceName*" }

    if ($privLink.PrivateLinkServiceConnectionState.Status -eq "Pending") {
            $appRequest = Approve-AzPrivateEndpointConnection -ResourceId $privLink.Id
            Write-Host "Private Link $PrivateLinkName status $($appRequest.PrivateLinkServiceConnectionState.Status)" 
    } 
    else {
            Write-Host "Private Link $PrivateLinkName status $($privLink.PrivateLinkServiceConnectionState.Status)"
    }
}
else {
    Write-Warning "Timeout Setting up Private Connection $PrivateLinkName"
}

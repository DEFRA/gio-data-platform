[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$applicationUrl,

    [Parameter(Mandatory = $false)]
    [string]$endpointPath = "/health",

    [Parameter(Mandatory = $true)]
    [string]$TenantID, 

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string]$siteDomain = ".azurewebsites.net"
)

. $PSScriptRoot\..\CommonFunctions.ps1
Write-Output "Checking health of: $applicationUrl$endpointPath"

[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module Az.Websites

Connect-UsingSP -userName $ClientId -pwd $ClientSecret -tenantId $TenantID -subscriptionId $SubscriptionId
$AppName = $AppName.ToLower().Replace("webaw12", "webaw10").Replace("webaf12", "webaf10")
$authorization = Get-AadTokenForWebApp -WebAppName $AppName -ClientIdKey "AdoSpClientId" -ClientSecretKey "AdoSpClientSecret" -KeyVaultName $KeyVaultName -Tenantid $TenantID

function CheckHealth ($url, $auth) {
    $status = Invoke-RestMethod -Method Get -Uri $url -Headers @{"Authorization" = $auth} -UseBasicParsing
    if ($null -ne $status) {
        foreach($item in $status.entries) {
            Write-Host "Component: $($item.key), Status: $($item.status), Additional Info: $($item.data)"
        }
    }
}

Retry {CheckHealth -url "$applicationUrl$endpointPath" -auth $authorization } -maxAttempts 5
[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$applicationName,

    [Parameter(Mandatory = $true)]
    [string]$slotName,

    [Parameter(Mandatory = $false)]
    [string]$siteDomain = '',

    [Parameter(Mandatory = $false)]
    [bool]$onlyRemoveRule = $false,

    [Parameter(Mandatory = $false)]
    [string]$changeIntervalInMinutes = '30',

    [Parameter(Mandatory = $false)]
    [string]$changeStep = '10',

    [Parameter(Mandatory = $false)]
    [string]$maxReroutePercentage = '75'
)

$rule = Get-AzWebAppTrafficRouting -ResourceGroupName "$resourceGroupName" -WebAppName "$applicationName"  -RuleName "$slotName" -ErrorAction SilentlyContinue
$hostName = "$applicationName-$slotName.$siteDomain"
if ($null -ne $rule) {
    Write-Output "Removing routing rule on $applicationName"
    Remove-AzWebAppTrafficRouting -ResourceGroupName "$resourceGroupName" -WebAppName "$applicationName" -RuleName "$slotName"
}

if ($onlyRemoveRule -eq $true) {
    $slotDetails = Get-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName -Slot $slotName -ErrorAction SilentlyContinue
    if ($null -ne $slotDetails) {
        Write-Output "Reset routing rule on $applicationName"
        Add-AzWebAppTrafficRouting -ResourceGroupName "$resourceGroupName" -WebAppName "$applicationName" -RoutingRule @{ActionHostName=$hostName;ReroutePercentage='0';Name=$slotName;}
    }
}
else{
    Write-Output "Adding routing rule on $applicationName"
    Add-AzWebAppTrafficRouting -ResourceGroupName "$resourceGroupName" -WebAppName "$applicationName" -RoutingRule @{ActionHostName=$hostName;ReroutePercentage='10';ChangeIntervalInMinutes=$changeIntervalInMinutes;MinReroutePercentage='10';MaxReroutePercentage=$maxReroutePercentage;ChangeStep=$changeStep;Name=$slotName;}
}   

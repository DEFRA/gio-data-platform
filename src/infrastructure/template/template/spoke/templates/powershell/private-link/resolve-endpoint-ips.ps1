param(
    [Parameter(Mandatory)][string]$TemplateOutput
)

Function Resolve-PrivateEndpointIDtoIP {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$ID)

    If (!($ID)) { Return $null }

    $private_endpoint = Get-AzResource -ResourceId $ID -ApiVersion '2020-07-01'
    $nic = Get-AzResource -ResourceId $private_endpoint.properties.networkInterfaces[0].id -ApiVersion '2020-07-01'

    #$ip = $nic.Properties.ipConfigurations[0].properties.privateIPAddress

    $Records = @()

    #Some Azure resources support multiple ips e.g. cosmos
    ForEach($privateIpAddress in $nic.Properties.ipConfigurations) 
    {
        $Records += $privateIpAddress.properties.privateIPAddress
    }

    Return $Records
}

$template_output_obj = $TemplateOutput | ConvertFrom-Json

$template_output_obj.privateEndpointDNSRecords.value | %{$_ | Add-Member -NotePropertyName ip -NotePropertyValue (Resolve-PrivateEndpointIDtoIP $_.id)}

$template_output_json_updated = $template_output_obj | ConvertTo-Json -Depth 9 -Compress

Write-Host "##vso[task.setvariable variable=templateOutputWithIPs]$template_output_json_updated"
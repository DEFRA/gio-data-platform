param(
    [Parameter(Mandatory)][string]$TemplateOutput
)

Function Set-PrivateEndpointDNSRecords {
    param($Records)
    ForEach ($record in $Records) {

        If (!($record.id)) { Continue }

        Write-Host "Setting record:"
        Write-Host "Zone: $($record.zone)"
        Write-Host "Name: $($record.record)"
        Write-Host "ID: $($record.id)"
        Write-Host "Value: $($record.ip)"

        $count = 0
        ForEach($ipAddress in $record.ip)
        {       
            $name = $record.record

            ##Service supports Secondary IP
            if ($count -gt 0)
            {
                $name = $record.record + "-" + $record.region
            }

              Write-Host "Deploying in region :" +  $record.region
            Write-Host "Name is :" $name

            New-AzPrivateDnsRecordSet `
            -Name $name `
            -ZoneName $record.zone `
            -ResourceGroupName $record.resourceGroup `
            -Ttl 10 `
            -RecordType 'A' `
            -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -Ipv4Address $ipAddress) `
            -Overwrite
            
            $count =  $count +1
        }          
    }
}

Write-Host "Template output JSON:"
Write-Host $TemplateOutput

$template_output_obj = $TemplateOutput | ConvertFrom-Json

Set-PrivateEndpointDNSRecords -Records $template_output_obj.privateEndpointDNSRecords.value
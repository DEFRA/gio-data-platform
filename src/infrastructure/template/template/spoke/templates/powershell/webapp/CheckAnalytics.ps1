[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$applicationId,

    [Parameter(Mandatory = $true)]
    [string]$applicationKey,

    [Parameter(Mandatory = $true)]
    [string]$appUrl,

    [Parameter(Mandatory = $false)]
    [int]$durationInDays = 1
)
[Net.ServicepointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output "Checking analytics data for: $appUrl"
for ($i = 0; $i -lt 2; $i++) {
    try {
        $headers = @{ "X-Api-Key" = "${applicationKey}:$applicationId"; "Content-Type" = "application/json" }

        Write-Output "Query: let days=$($durationInDays)d;app('$applicationId').requests | where url startswith '$appUrl' and success == False | where timestamp > ago(days) | project operation_Name, application_Version, duration"
        $query = @{"query" = "let days=$($durationInDays)d;app('$applicationId').requests | where url startswith '$appUrl' and success == False | where timestamp > ago(days) | project operation_Name, application_Version, duration"}
        Write-Output $query.Values

        $body = ConvertTo-Json $query | % { [regex]::Unescape($_) }
        Write-Output $body

        $result = Invoke-RestMethod "https://api.applicationinsights.io/v1/apps/$applicationId/query" -H $headers -Body $body -Method POST
    }
    catch {
        Write-Output "An error occurred:"
        Write-Output $_
    }
}

if (($null -ne $result) -and ($result.tables[0].rows.Count -ne 0)) {
    Write-Warning "Health Check Failed"
}

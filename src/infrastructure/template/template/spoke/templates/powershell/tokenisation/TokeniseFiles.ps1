param(
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$RootFolder
 )

[Net.ServicepointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

$json = Get-Content $ConfigFile | ConvertFrom-Json;

foreach ($x in $json)
{
    $fullPath = $RootFolder + "/" + $x.RelativeFilePath

    Write-Host $fullPath

    $environmentVariableValue = [System.Environment]::GetEnvironmentVariable($x.EnvironmentVariable)

    Write-Host "Environment Variable : $($x.EnvironmentVariable) with value : $environmentVariableValue" 

    ((Get-Content -path $fullPath -Raw) -replace $x.TokenToReplace,$environmentVariableValue) | Set-Content -Path $fullPath
}
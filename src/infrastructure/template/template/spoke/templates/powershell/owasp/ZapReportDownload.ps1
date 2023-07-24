[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$filePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$fileName
)

$accountDetails = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts | Where-Object { $_.Name -eq $storageAccountName }
$storageAccount = Get-AzStorageAccount -ResourceGroupName $accountDetails.ResourceGroupName -Name $storageAccountName

Write-Host "Downloading scan report from storage account..."
$destinationFolder = $Env:BUILD_ARTIFACTSTAGINGDIRECTORY
Get-AzStorageFileContent -ShareName owaspresults -Context $storageAccount.Context -Path "$filePath\$fileName.xml" -Destination $destinationFolder -Force
Get-AzStorageFileContent -ShareName owaspresults -Context $storageAccount.Context -Path "$filePath\$fileName.html" -Destination $destinationFolder -Force

Write-Host "Transforming scan report..."
$XslPath = "$($Env:SYSTEM_DEFAULTWORKINGDIRECTORY)\templates\powershell\owasp\OWASPToNUnit3.xslt"
$XmlInputPath = "$($Env:BUILD_ARTIFACTSTAGINGDIRECTORY)\$fileName.xml"
$XmlOutputPath = "$($Env:BUILD_ARTIFACTSTAGINGDIRECTORY)\Converted-$fileName.xml"
$XslTransform = New-Object System.Xml.Xsl.XslCompiledTransform
$XslTransform.Load($XslPath)
$XslTransform.Transform($XmlInputPath, $XmlOutputPath)

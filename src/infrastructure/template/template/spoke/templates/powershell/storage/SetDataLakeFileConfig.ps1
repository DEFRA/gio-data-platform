[CmdletBinding()]
	param(
	   [Parameter(Mandatory=$true)][string]$DataLakeAccountName,
       [Parameter(Mandatory=$true)][string]$ContainerName,
       [Parameter(Mandatory=$true)][string]$ConfigurationPath,
       [Parameter(Mandatory=$true)][string]$ConfigurationFolderName
    )

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $ctx = New-AzStorageContext -StorageAccountName $DataLakeAccountName -UseConnectedAccount    
          
    $configFiles = Get-ChildItem -File -Path $ConfigurationPath
    
   foreach($configFile in $configFiles)
   { 
      $destPath = $ConfigurationFolderName + "/" + $configFile
      $fullFile = $ConfigurationPath + "/" + $configFile 
      New-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $destPath -Source $fullFile -Force
   }

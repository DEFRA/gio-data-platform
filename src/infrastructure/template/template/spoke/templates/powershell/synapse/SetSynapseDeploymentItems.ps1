[CmdletBinding()] 
param(
[string][Parameter(Mandatory=$true)] $IncludedTypes,
[string][Parameter(Mandatory=$true)] $SourceFileFullPath,
[string][Parameter(Mandatory=$true)] $IncludedFolders
)

$IncludedTypesArray = $IncludedTypes -split ","
$IncludedFoldersArray = $IncludedFolders -split ","

[Net.ServicepointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

$item = Get-Content $SourceFileFullPath | ConvertFrom-Json;

$newItem = $item.PsObject.Copy()
$newItem.resources = @();

$removedItems = New-Object -TypeName "System.Collections.ArrayList"

foreach ($x in $item.resources)
{    
    if ($IncludedTypesArray -contains $x.type -and $IncludedFoldersArray -contains $x.properties.folder.name)
    {
        $newItem.resources += $x;
        Write-Host "Keeping" $x.name "of type" $x.type  
    }
    else
    {
        Write-Host "Removing" $x.name "of type" $x.type  
        $removedItems.Add($x.name)
    }
}


foreach ($x in $newItem.resources)
{ 
    $depOn = New-Object -TypeName "System.Collections.ArrayList"
    foreach ($dep in $x.dependsOn)
    {
        $exists = $false

        foreach ($remDep in $removedItems)
        {
            $depName = $remDep.replace("[concat(parameters('workspaceName'), '", "")
            if ($dep.contains($depName))
            {
               $exists = $true
            }
        }

        if (!$exists)
        {
            $depOn.Add($dep)
        }
    }

    $x.dependsOn = $depOn
}

$json =  ConvertTo-Json -Depth 100 -InputObject $newItem -Compress

$jsonCleaned = [regex]::replace(
  $json, 
  '(?<=(?:^|[^\\])(?:\\\\)*)\\u(00(?:26|27|3c|3e))', 
  { param($match) [char] [int] ('0x' + $match.Groups[1].Value) },
  'IgnoreCase'
)

$jsonCleaned | Out-File  -FilePath $SourceFileFullPath;
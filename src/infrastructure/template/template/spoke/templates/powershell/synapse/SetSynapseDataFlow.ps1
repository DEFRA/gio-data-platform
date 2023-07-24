param(
    [Parameter(Mandatory=$true)][string]$SynapseWorkspaceName,
    [Parameter(Mandatory=$true)][string]$SourceFile,
    [Parameter(Mandatory=$true)][string]$TempDirectory,
    [Parameter(Mandatory=$false)][string]$ReplaceToken=$null,
    [Parameter(Mandatory=$false)][string]$ReplaceTokenValue=$null,
    [Parameter(Mandatory=$false)][string]$EnvironmentPrefix       
 )

[Net.ServicepointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

mkdir $TempDirectory;

$item = Get-Content $SourceFile | ConvertFrom-Json;

foreach ($x in $item.resources |  Where-Object { $_.type -eq "Microsoft.Synapse/workspaces/dataflows" })
{
     if ($x.properties.typeProperties.script.Contains("delta"))
     {       
          if($null -ne $x.properties.description)
          {
            $x.properties.description = $x.properties.description + '.';
          }
          else 
          {
              $x.properties | Add-Member -NotePropertyName description -NotePropertyValue '.';
          }
              
          $extractedName = [regex]::matches($x.name,'[\/]\w*').value.Replace('/','');

          $x.name = $extractedName;

          $json = ConvertTo-Json -Depth 100 -InputObject $x; #-Compress

          if ($ReplaceTokenValue -and $ReplaceToken)
          {
            $json = $json.Replace($ReplaceToken,$ReplaceTokenValue);
          }

          $json = $json.Replace("devtrf",$EnvironmentPrefix.ToLower() + "trf");
                    
          $json | Out-File  -FilePath "$TempDirectory\$extractedName.json";
          Set-AzSynapseDataFlow -WorkspaceName $SynapseWorkspaceName -Name $extractedName -DefinitionFile "$TempDirectory\$extractedName.json"
      }
}
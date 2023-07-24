# .\Set-KeyVaultSecrets.ps1 -keyVaultName "some-key-vault" -variables @{ Test1 = "Value1"; Test2 = "" }  

[CmdletBinding()]
Param
(
  [Parameter(Mandatory = $true)]
  [string]$keyVaultName,

  [Parameter(Mandatory = $true)]
  [object]$variables,

  [Parameter()]
  [switch]$errorIfEmpty = $false
)

. $PSScriptRoot\..\CommonFunctions.ps1

Write-Host "$($variables.Count) varible(s) found."

foreach ($variable in $variables.GetEnumerator()) {
  try
  {
    $name = $variable.Name;

    if (($variable.Value -eq "") -or ($null -eq $variable.Value)) {
      if ($errorIfEmpty) {
        Write-Output "##vso[task.logissue type=error]'$name' has no value."
      } else {
        Write-Output "##vso[task.logissue type=warning]Skipping '$name', no value."
      }
      Continue;
    }
    
    $existingSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $name -WarningAction Ignore
    
    if (($null -ne $existingSecret) -And (Get-PlainText $existingSecret.SecretValue) -eq $variable.Value) {
      Write-Host "Skipping '$name', value matches."
      Continue;
    }

    $secret = ConvertTo-SecureString -String $variable.Value -AsPlainText -Force

    Write-Host "Setting '$name'..."
    Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $name -SecretValue $secret
  }
  catch 
  {
    Write-Error "An error occurred:"
    Write-Error $_
    Write-Error $_.Message
  }
}

Write-Host "Complete."

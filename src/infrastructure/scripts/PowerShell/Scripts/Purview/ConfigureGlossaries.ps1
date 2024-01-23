param (
    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

Import-Module $PSScriptRoot/../../Modules/Purview/PurviewModule.psm1 -Force
$jsonFiles = Get-ChildItem -Path $ConfigFilePath -Filter "*.json" -Recurse

$baseUrl = "https://$AccountName.purview.azure.com"

foreach ($file in $jsonFiles) 
{
  $config = Get-Content $file.FullName | ConvertFrom-Json

  foreach ($glossary in $config.Glossaries) 
  {  
        $experts = @()
        $stewards = @()

        foreach ($exp in $glossary.Experts)
        {
            $experts += @{
                    id = $exp.Id
                    info = $exp.Info
                }
        }

        foreach ($ste in $glossary.Stewards)
        {
            $stewards += @{
                    id = $ste.Id
                    info = $ste.Info
                }
        }

        $id = Set-Glossary -glossaryName $glossary.Name -glossaryDescription $glossary.Description -experts $experts -stewards $stewards -BaseUri $baseUrl
        
        Write-Host "Glossary Upserted with ID $($id.guid)"
       
        foreach($term in $glossary.Terms)
        {
            Write-Host "Setting GlossaryTerms"
            Set-GlossaryTerm -glossaryName $glossary.Name -BaseUri $baseUrl -TermObject $term -GlossaryId $id.guid
        } 
       
        foreach($workflow in $glossary.WorkFlows)
        {
            Write-Host "Setting Glossary Workflows"
            Set-Workflow -WorkFlow $workflow -BaseUri $baseUrl -GlossaryId $id.guid
        }         

  }
}

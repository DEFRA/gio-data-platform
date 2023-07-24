[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$publishProject,

    [Parameter(Mandatory = $true)]
    [string]$apiConfig,

    [Parameter(Mandatory = $true)]
    [string]$apiProjectName
)

$publishProjectPath = Get-ChildItem $publishProject -r

$item = Get-ChildItem $apiConfig -r
$apiConfigPath = ($item).DirectoryName
$apiConfigFilePath = ($item).FullName

dotnet publish ($publishProjectPath).FullName --output publish_output_templates --runtime win-x64

dotnet new tool-manifest --force
dotnet tool install swashbuckle.aspnetcore.cli --version 5.6.3
dotnet tool install ArmTemplates.Custom --version 1.0.3 --add-source .\Defra.TRD.Pipeline.Common\packages --ignore-failed-sources

$tempPublishOutputPath = "$Env:Build_SourcesDirectory\publish_output_templates"

Copy-Item "$tempPublishOutputPath\$($apiProjectName).xml" -Destination "$tempPublishOutputPath\dotnet-swagger.xml"

$templatesPath="$($Env:Build_SourcesDirectory)\publish-templates"

if (!(Test-Path $templatesPath)){
    New-Item -ItemType "directory" -Path $templatesPath
}

$yamlObject = Get-Content -raw $apiConfigFilePath | ConvertFrom-Yaml

Set-Location $tempPublishOutputPath

$versions =@();

Foreach($api in $yamlObject.Apis){

    $apiVersion = ($api.openApiSpec.Split('\'))[0]
    $apiSwagger = ($api.openApiSpec.Split('\'))[1]

    if(!$versions.Contains($apiVersion)) {
        if (!(Test-Path $apiConfigPath\$apiVersion)) {
            New-Item -ItemType "directory" -Path $apiConfigPath\$apiVersion
        }
        dotnet swagger tofile --output $apiConfigPath\$apiVersion\$apiSwagger $tempPublishOutputPath\$apiProjectName.dll $apiVersion
        $versions+=$apiVersion
    }
}

Set-Location $apiConfigPath
dotnet api-template-generator create --configFile $apiConfigFilePath --outputLocation $templatesPath

if (!(Test-Path $Env:Build_ArtifactStagingDirectory\publish-templates)){
    New-Item -ItemType "directory" -Path $Env:Build_ArtifactStagingDirectory\publish-templates
}

Copy-Item $templatesPath -Destination $Env:Build_ArtifactStagingDirectory -recurse -Force

"##vso[task.setvariable variable=apimApiTemplate]$($yamlObject.baseFileName)"
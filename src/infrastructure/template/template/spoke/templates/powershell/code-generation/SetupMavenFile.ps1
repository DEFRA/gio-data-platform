[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$apiName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$artifactFeed,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$certificatePwd
)
Write-Host "Updating Maven POM file..."
$items = @("repositories","distributionManagement")
$fileName = "$($Env:BUILD_SOURCESDIRECTORY)/$apiName/java-client/pom.xml"

$mavenNamespace = 'http://maven.apache.org/POM/4.0.0'
$xmlDoc = [System.Xml.XmlDocument](Get-Content $fileName)
foreach( $item in $items) {                
    $repos = $xmlDoc.project.AppendChild($xmlDoc.CreateElement($item, $mavenNamespace))
    $repo = $repos.AppendChild($xmlDoc.CreateElement("repository", $mavenNamespace))
    $id = $repo.AppendChild($xmlDoc.CreateElement("id", $mavenNamespace))
    $id.AppendChild($xmlDoc.CreateTextNode($artifactFeed)) | Out-Null
    
    $url = $repo.AppendChild($xmlDoc.CreateElement("url", $mavenNamespace))
    if ($artifactFeed -ne 'DEFRA-__PRJ__') {
        $url.AppendChild($xmlDoc.CreateTextNode("https://pkgs.dev.azure.com/defragovuk/_packaging/$artifactFeed/maven/v1")) | Out-Null
    }
    else {
        $url.AppendChild($xmlDoc.CreateTextNode("https://pkgs.dev.azure.com/defragovuk/DEFRA-__PRJ__-PUBLIC/_packaging/$artifactFeed/nuget/v3/index.json")) | Out-Null
    }
    
    $releases = $repo.AppendChild($xmlDoc.CreateElement("releases", $mavenNamespace))
    $enabled = $releases.AppendChild($xmlDoc.CreateElement("enabled", $mavenNamespace))
    $enabled.AppendChild($xmlDoc.CreateTextNode("true")) | Out-Null
    
    $snapshot = $repo.AppendChild($xmlDoc.CreateElement("snapshots", $mavenNamespace))
    $snapenabled = $snapshot.AppendChild($xmlDoc.CreateElement("enabled", $mavenNamespace))
    $snapenabled.AppendChild($xmlDoc.CreateTextNode("true")) | Out-Null
}

$plugin = $xmlDoc.project.build.plugins.AppendChild($xmlDoc.CreateElement("plugin", $mavenNamespace))
$elem = $plugin.AppendChild($xmlDoc.CreateElement("groupId", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("org.apache.maven.plugins")) | Out-Null
$elem = $plugin.AppendChild($xmlDoc.CreateElement("artifactId", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("maven-jarsigner-plugin")) | Out-Null
$elem = $plugin.AppendChild($xmlDoc.CreateElement("version", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("3.0.0")) | Out-Null
$elem = $plugin.AppendChild($xmlDoc.CreateElement("executions", $mavenNamespace))
$exec = $elem.AppendChild($xmlDoc.CreateElement("execution", $mavenNamespace))
$elem = $exec.AppendChild($xmlDoc.CreateElement("id", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("sign")) | Out-Null
$goals = $exec.AppendChild($xmlDoc.CreateElement("goals", $mavenNamespace))
$elem = $goals.AppendChild($xmlDoc.CreateElement("goal", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("sign")) | Out-Null

$config = $plugin.AppendChild($xmlDoc.CreateElement("configuration", $mavenNamespace))
$elem = $config.AppendChild($xmlDoc.CreateElement("keystore", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("$env:BUILD_SOURCESDIRECTORY\codesign.jks")) | Out-Null
$elem = $config.AppendChild($xmlDoc.CreateElement("alias", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("$env:JavaCertAlias")) | Out-Null
$elem = $config.AppendChild($xmlDoc.CreateElement("keypass", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode('"' + $certificatePwd + '"')) | Out-Null
$elem = $config.AppendChild($xmlDoc.CreateElement("storepass", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("$env:JavaStorePass")) | Out-Null
$elem = $config.AppendChild($xmlDoc.CreateElement("verify", $mavenNamespace))
$elem.AppendChild($xmlDoc.CreateTextNode("true")) | Out-Null

$xmlDoc.Save($fileName)
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$certificateString,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$certificatePwd
)

$kvSecretBytes = [System.Convert]::FromBase64String("$certificateString")
$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$certCollection.Import($kvSecretBytes,$null,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

#Get the file created
$protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $certificatePwd)
$pfxPath = "$env:BUILD_SOURCESDIRECTORY\DefraCodeSigning-live.pfx"
[System.IO.File]::WriteAllBytes($pfxPath, $protectedCertificateBytes)
Write-Host "Signing certificate available at $pfxPath"

$javaTempStorePass = (([int][char]'a'..[int][char]'z' | %{[char]$_}) | Get-Random -Count 12) -join ''
$javaTempStorePath = "$env:BUILD_SOURCESDIRECTORY\codesign.jks"

$params = @(
  '-importkeystore',
  '-srckeystore',
  $pfxPath,
  '-srcstoretype',
  'pkcs12',
  '-destkeystore',
  $javaTempStorePath,
  '-deststoretype',
  'JKS',
  '-deststorepass',
  $javaTempStorePass,
  '-srcstorepass',
  $certificatePwd
)

Start-Process -FilePath "$env:JAVA_HOME\bin\keytool.exe" `
            -ArgumentList $params `
            -RedirectStandardOutput "$env:AGENT_TEMPDIRECTORY\keytool_stdout.txt" `
            -RedirectStandardError "$env:AGENT_TEMPDIRECTORY\keytool_stderr.txt" `
            -NoNewWindow -Wait

$keytool_out = Get-Content "$env:AGENT_TEMPDIRECTORY\keytool_stderr.txt" -Raw
If ($keytool_out -match 'alias ({.*?}) successfully imported') {
    $javaCodeSignCertAlias = $matches[1]
} Else {
    Write-Host '##vso[task.logissue type=error]Could not import pfx to java keystore'
    Exit 1
}

Write-Host "Certificate keystore alias: $javaCodeSignCertAlias"
Write-Host "##vso[task.setvariable variable=JavaCertAlias;]$javaCodeSignCertAlias"
Write-Host "##vso[task.setvariable variable=JavaStorePass;]$javaTempStorePass"
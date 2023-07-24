<#
    .SYNOPSIS
       Powershell for Common Functions.
    .DESCRIPTION
        This script contains all the Powershell related common functionality
#>

Function Get-PlainText()
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline=$true, Mandatory = $true, Position=0)]
        [System.Security.SecureString]$SecureString
    )
    BEGIN { }
    PROCESS
    {
        $marshal = [System.Runtime.InteropServices.Marshal]
        $bstr = $marshal::SecureStringToBSTR($SecureString);

        try
        {
            $plainTextStr = $marshal::PtrToStringBSTR($bstr);
            $marshal::ZeroFreeBSTR( $bstr )
            Return $plainTextStr
        }
        finally
        {
            [Runtime.InteropServices.Marshal]::FreeBSTR($bstr);
        }
    }
    END { }
}

Function Connect-UsingSP {
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$pwd,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$tenantId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$subscriptionId
    )

    $PWord = ConvertTo-SecureString -String $pwd -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $userName, $PWord
    
    Connect-AzAccount -Credential $Credential -Tenant $tenantId -Subscription $subscriptionId -ServicePrincipal
}

Function Get-AadTokenForWebApp {

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebAppName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientIdKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientSecretKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Tenantid
    )
    $site = Get-AzResource -ResourceType Microsoft.Web/sites | Where-Object { $_.Name -eq $WebAppName }
    $app = Get-AzWebApp -ResourceGroupName $site.ResourceGroupName -Name $WebAppName
    $secretPrefix = $app.ServerFarmId -replace '.*/' 
    $secretPrefix = $secretPrefix.Substring(3)

    Write-Host "Reading secrets from Keyvault..."
    $resourceSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$secretPrefix-OAuth-ClientId"
    $clientId = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ClientIdKey
    $clientIdSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ClientSecretKey

    $plainTextClientId = $clientId.SecretValue | Get-PlainText
    $plainTextResourceId = $resourceSecret.SecretValue | Get-PlainText
    $resouceId = "$plainTextResourceId/.default"

    $result = Get-AadToken -ClientId $plainTextClientId -ClientSecret $clientIdSecret.SecretValue -ResouceId $resouceId -Tenantid $Tenantid
    $authorization = "{0} {1}" -f ($result.token_type , $result.access_token)
    return $authorization
}

Function Get-AadToken {

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString]$ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResouceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Tenantid
    )
    try {  
        Write-Host "Generating a token..."
        $plainTextSecret = $ClientSecret | Get-PlainText
        $result = Invoke-RestMethod -Uri https://login.microsoftonline.com/$Tenantid/oauth2/v2.0/token -Method Post -Body @{"grant_type" = "client_credentials"; "scope" = "$ResouceId"; "client_id" = "$ClientId"; "client_secret" = "$plainTextSecret" }
        return $result
    }
    catch [System.Exception] {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Exception ($ErrorMessage)"
        throw "ERROR: Get-AadToken failed."
    }
}

Function Get-KVSecret {

    param(
        [Parameter(Mandatory)][string]$VaultName,
        [Parameter(Mandatory)][string]$SecretName
    )

    $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -WarningAction Ignore
    $secret_plain = Get-PlainText $secret.SecretValue
    Return $secret_plain
}

function Retry()
{
    param(
        [Parameter(Mandatory=$true)][Action]$action,
        [Parameter(Mandatory=$false)][int]$maxAttempts = 3
    )
    $attempts=1    
    $ErrorActionPreferenceToRestore = $ErrorActionPreference
    $ErrorActionPreference = "Stop"

    do
    {
        try
        {
            $action.Invoke();
            break;
        }
        catch [Exception]
        {
            Write-Host $_.Exception
        }

        # exponential backoff delay
        $attempts++
        if ($attempts -le $maxAttempts) 
        {
            $retryDelaySeconds = [math]::Pow(2, $attempts)
            $retryDelaySeconds = $retryDelaySeconds - 1  # Exponential Backoff Max == (2^n)-1
            Write-Host("Action failed. Waiting " + $retryDelaySeconds + " seconds before attempt " + $attempts + " of " + $maxAttempts + ".")
            Start-Sleep -Milliseconds $retryDelaySeconds            
        }
        else 
        {
            $ErrorActionPreference = $ErrorActionPreferenceToRestore
            Write-Error $_.Exception.Message
        }
    } while ($attempts -le $maxAttempts)

    $ErrorActionPreference = $ErrorActionPreferenceToRestore
}

Function ComputePassword {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.GenerateKey()
    return $([System.Convert]::ToBase64String($aesManaged.Key)) | ConvertTo-SecureString -AsPlainText -Force
}

function PasswordToString {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SecureString]$Password
    )
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}
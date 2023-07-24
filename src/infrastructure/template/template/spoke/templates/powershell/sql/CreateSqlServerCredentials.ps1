<#
	.SYNOPSIS
	.DESCRIPTION
		This script sets a user name and password for a SQL Database. It will not over-write existing passwords or user names. 
		Please use Azure Automation Runbook for this.
#>
Param (
	[Parameter(Mandatory = $false)]
	[AllowNull()]
	[Nullable[DateTime]]$ExpiryTime,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$KeyVaultName,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$SecretNameSqlUserId,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$SqlDbUserNameValue,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$SecretNameSqlPassword
	)

$contentType = 'string'
. $PSScriptRoot\..\CommonFunctions.ps1
# Ensure secret does not exist (username)
$secretExists = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretNameSqlUserId
# Create and Set the Passwords in KV
If ($secretExists -eq $null) {
    $SqlDbUserNameValueSecured = ConvertTo-SecureString $SqlDbUserNameValue -AsPlainText -Force
    Write-Output "[Start] Update KeyVault Secret for SQL User Name as it does not exist"
    Set-AzKeyVaultSecret  -VaultName $KeyVaultName -Name $SecretNameSqlUserId -SecretValue $SqlDbUserNameValueSecured -ContentType $contentType
    Write-Output "[Finish] Updated KeyVault Secret"
} else 	{
    Write-Output "User-name already exists in KV - Skipping"
}

# Ensure secret does not exist (pw)
$secretExists = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretNameSqlPassword
If($secretExists -eq $null)	{
    $sqlPassword = ComputePassword
    If($ExpiryTime -eq $null)
    {
        $currentDate = Get-Date
        $ExpiryTime = ($currentDate.AddYears(1))
        Write-Output "Expiry Time is Null. Setting to default of 1 year."
    }
    Write-Output "[Start] Update KeyVault Secret for SQL Password with expiry date as it does not exist"
    Set-AzKeyVaultSecret  -VaultName $KeyVaultName -Name $SecretNameSqlPassword -SecretValue $sqlPassword -Expires $ExpiryTime -ContentType $contentType
    Write-Output "[Finish] Updated KeyVault Secret"
} else {
    Write-Output "Password already exists in KV - Skipping"
}

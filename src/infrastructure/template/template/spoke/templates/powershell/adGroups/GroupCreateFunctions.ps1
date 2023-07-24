function New-ADGroup() {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $True)]
        [Object]$group,

        [Parameter(Mandatory = $True)]
        [string]$graphApiVersion,

        [Parameter(Mandatory = $True)]
        [Object]$headers,

        [Parameter(Mandatory = $False)]
        [string]$groupOwners = $env:defraDefaultGroupOwner
    )

    $graphUri = "https://graph.microsoft.com"

    Write-Host "Creating AAD Group...$($group.displayName)."
       
    $groupUri = "$($graphUri)/$($graphApiversion)/groups?`$filter=(displayName eq '$($group.displayName)')&`$select=id"
    $groupObject = Invoke-RestMethod -Uri $groupUri -Method GET -Headers $headers

    if (-not($groupObject.value)) {
        $ownerArr = $groupOwners.Split(",")
        $ownerOdataArr = [string[]]::new($ownerArr.Count)
        for ( $index = 0; $index -lt $ownerArr.count; $index++)
        {
            $ownerOdataArr[$index] = "$($graphUri)/$($graphApiversion)/users/$($ownerArr[$index])"
        }

        $postBody = @{
            displayName     = $group.displayName
            mailEnabled     = $group.mailEnabled
            mailNickname    = $group.mailNickname
            securityEnabled = $group.securityEnabled
            "owners@odata.bind" = $ownerOdataArr
        }
        try{
            $newGroup = Invoke-RestMethod -Uri "$($graphUri)/$($graphApiversion)/groups" -Method Post -Body ($postBody | ConvertTo-Json) -Headers $headers
        }
        catch{
            Write-Host "Failed to add owner to group. Retry adding group only."
            $postBody = @{
                displayName     = $group.displayName
                mailEnabled     = $group.mailEnabled
                mailNickname    = $group.mailNickname
                securityEnabled = $group.securityEnabled
            }
            $newGroup = Invoke-RestMethod -Uri "$($graphUri)/$($graphApiversion)/groups" -Method Post -Body ($postBody | ConvertTo-Json) -Headers $headers
        }

        if ($group.keyVault) {

            foreach ($secret in $group.keyVault.secrets) {
                $contentType = "GUID"
                $tempVal = $newGroup.id
                $secretValue = ConvertTo-SecureString $tempVal -AsPlainText -Force
                $endData = Get-Date -Year 2099 -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59
                
                Write-Output "Adding new secret '$($secret.key)' to '$($group.keyVault.name)'"
                Set-AzKeyVaultSecret -VaultName $group.keyVault.name -Name $secret.key -SecretValue $secretValue -ContentType $contentType -Expires $endData | Out-Null
            }
        }

        Write-Host "Succesfully created AAD Group..."
    }
    else {
        Write-Host "Group already exists.."
    }
}
function New-ADGroups() {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$jsonFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$graphApiversion,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$tokenResource = "https://graph.microsoft.com",

        [Parameter(Mandatory = $false)]
        [Object]$headers = $null
    )

    $addGroups = (Get-Content $jsonFilePath -Raw) | ConvertFrom-Json

    if ($null -eq $headers) {
        Write-Verbose "Getting AccessToken for '$($tokenResource)'..."
        $token = (Get-AzAccessToken -Resource $tokenResource).Token

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Bearer $token")
    }

    foreach ($group in $addGroups.groups) {
        New-ADGroup -group $group -graphApiVersion $GraphApiversion -headers $headers
    }
}
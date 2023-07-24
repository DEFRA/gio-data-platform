Function Add-Update-AadApp {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $True)]
        [Object]$app,

        [Parameter(Mandatory = $True)]
        [string]$graphApiVersion,

        [Parameter(Mandatory = $True)]
        [Object]$headers
    )

    $graphApiBaseUrl = "https://graph.microsoft.com"
    $applicationsUri = "$graphApiBaseUrl/$graphApiVersion/applications"
    $servicePrincipalUri = "$graphApiBaseUrl/$graphApiVersion/servicePrincipals"
    $filter = '?$filter=displayName+eq+' + "'{0}'"
    $applications = Invoke-RestMethod -Method GET -Headers $headers -Uri $($applicationsUri + $filter -f $($app.displayName))
    $newApp = $applications.value.Length -eq 0
    if (-not $newApp) {
        $application = $applications.value | Where-Object { $_.displayName -eq $app.displayName }
    }

    Write-Verbose "Building Application Body for $($app.displayName)..."
    $applicationJson = @{}
    $applicationJson.Add("displayName", $app.displayName)
    
    if ($app.requiredResourceAccess) {
        $requiredResourceAccess = New-Object System.Collections.ArrayList
        foreach ($requiredResource in $app.requiredResourceAccess) {
            $resource = $requiredResource
            if ($requiredResource.referenceResourceName) {
                $resourceAccess = @()
                if ($requiredResource.roles) {
                    Write-Verbose "Assigning '$($requiredResource.referenceResourceName)' Application API Roles..."
                    $applications = Invoke-RestMethod -Method GET -Headers $headers -Uri $($applicationsUri + $filter -f $($requiredResource.referenceResourceName))
                    $referenceApp = $applications.value | Where-Object { $_.displayName -eq $requiredResource.referenceResourceName }
                    foreach ($role in $requiredResource.roles) {
                        $appRole = $referenceApp.appRoles | Where-Object { $_.value -eq $role }
                        $resourceAccess += New-Object psobject -property @{id = $appRole.id; type = 'Role' }
                    }
                    $resource = New-Object psobject -property @{resourceAppId = $referenceApp.appId; resourceAccess = $resourceAccess }
                }
                else {
                    Write-Verbose "Assigning '$($requiredResource.referenceResourceName)' Application API Scope..."
                    $servicePrincipals = Invoke-RestMethod -Method GET -Headers $headers -Uri $($servicePrincipalUri + $filter -f $($requiredResource.referenceResourceName))
                    $servicePrincipal = $servicePrincipals.value | Where-Object { $_.displayName -eq $requiredResource.referenceResourceName }

                    $resourceAccess += New-Object psobject -property @{id = $servicePrincipal.oauth2PermissionScopes[0].id; type = 'Scope' }
                    $resource = New-Object psobject -property @{resourceAppId = $servicePrincipal.appId; resourceAccess = $resourceAccess }
                }
            }
            $requiredResourceAccess.Add($resource) | Out-Null
        }
        $applicationJson.Add("requiredResourceAccess", $requiredResourceAccess)
    }

    if ($app.appRoles) {
        foreach ($role in $app.appRoles) {
            if (-not $newApp) {
                $existingRole = $application.appRoles | Where-Object { $_.value -eq $role.value }
                if ($existingRole) {
                    $role.id = $existingRole.id
                }
            }
            if ($role.id -eq "") {
                $role.id = $(New-Guid).Guid
            }
        }
        Write-Verbose "Adding application Roles: $($app.appRoles)"
        $applicationJson.Add("appRoles", $app.appRoles)
    }

    if($app.optionalClaims) {
        Write-Verbose "Adding application Optional Claims: $($app.optionalClaims)"
        $applicationJson.Add("optionalClaims", $app.optionalClaims)
    }

    if($app.groupMembershipClaims){
        Write-Verbose "Adding application GroupMembership Claims: $($app.groupMembershipClaims)"
        $applicationJson.Add("groupMembershipClaims", $app.groupMembershipClaims)
    }

    if ($app.publicClient) {
        Write-Verbose "Setting the application as public client..."
        $applicationJson.Add("isFallbackPublicClient", $app.isPublicClient)
        $applicationJson.Add("publicClient", $app.publicClient)
    }
    if ($app.web) {
        $applicationJson.Add("web", $app.web)
    }
    if ($app.signInAudience) {
        $applicationJson.Add("signInAudience", $app.signInAudience)
    }
    else {
        $applicationJson.Add("signInAudience", "AzureADMyOrg")
    }
    if ($app.api) {
        if ($app.api.oauth2PermissionScopes) {
            if ($newApp) { Write-Verbose "Adding OAUTH2 Scope..." }
            foreach ($perm in $app.api.oauth2PermissionScopes) {
                $perm.id = $(New-Guid).Guid
            }
        }
        if (-not $newApp -and $application.api.oauth2PermissionScopes.Length -ne 0) {
            $app.api.PSObject.properties.Remove('oauth2PermissionScopes')
        }

        if ($app.api.PSObject.properties.Length -gt 0) {
            $applicationJson.Add("api", $app.api)
        }
    }

    Write-Verbose "Payload: $($applicationJson | ConvertTo-Json -Depth 100)"
    if ($newApp) {
        Write-Output "Creating Application '$($app.displayName)'"
        $application = Invoke-RestMethod -Method Post -Headers $headers -Uri $applicationsUri -Body ($applicationJson | ConvertTo-Json -Depth 100)

        $servicePrincipals = Invoke-RestMethod -Method GET -Headers $headers -Uri $($servicePrincipalUri + $filter -f $($app.displayName))
        if ($servicePrincipals.value.Length -eq 0) {
            $spJson = @{}
            $spJson.Add("appId", $application.appId)
            if ($app.appRoles) {
                $spJson.Add("appRoleAssignmentRequired", $True)
            }

            Write-Output "Creating Service Principal for '$($app.displayName)'"
            Invoke-RestMethod -Method Post -Headers $headers -Uri $servicePrincipalUri -Body ($spJson | ConvertTo-Json -Depth 100) | Out-Null
        }

        if ($app.keyVault) {
            foreach ($secret in $app.keyVault.secrets) {
                if ($secret.type -and $secret.type -eq 'Password') {
                    $name = @{}
                    $name.Add("displayName", "ADO")
                    $pwdBody = @{}
                    $pwdBody.Add("passwordCredential", $name)

                    Write-Output "Creating Application Secret for '$($app.displayName)'"
                    $passwordResponse = Invoke-RestMethod -Method Post -Headers $headers -Uri "$applicationsUri/$($application.id)/addPassword" -Body ($pwdBody | ConvertTo-Json -Depth 10)
                    $contentType = "Secret"
                    $secretValue = ConvertTo-SecureString $passwordResponse.secretText -AsPlainText -Force
                    $endData = Get-Date -Date $passwordResponse.endDateTime
                }
                elseif ($secret.type -and $secret.type -eq 'ClientSecret') {
                    $name = @{}
                    $name.Add("displayName", "ADO")
                    $pwdBody = @{}
                    $pwdBody.Add("passwordCredential", $name)

                    Write-Output "Creating Application Secret for '$($app.displayName)'"
                    $passwordResponse = Invoke-RestMethod -Method Post -Headers $headers -Uri "$applicationsUri/$($application.id)/addPassword" -Body ($pwdBody | ConvertTo-Json -Depth 10)
                    $contentType = "Secret"
                    $secretValue = ConvertTo-SecureString $passwordResponse.secretText -AsPlainText -Force
                    $endData = Get-Date -Date $passwordResponse.endDateTime
                }
                else {
                    $contentType = "GUID"
                    $tempVal = $application.$($secret.valueKey)
                    $secretValue = ConvertTo-SecureString $tempVal -AsPlainText -Force
                    $endData = Get-Date -Year 2099 -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59
                }
                Write-Output "Adding new secret '$($secret.key)' to '$($app.keyVault.name)'"
                Set-AzKeyVaultSecret -VaultName $app.keyVault.name -Name $secret.key -SecretValue $secretValue -ContentType $contentType -Expires $endData | Out-Null
            }
        }
    }
    else {
        Write-Output "Updating Application '$($app.displayName)'"
        Invoke-RestMethod -Method Patch -Headers $headers -Uri "$applicationsUri/$($application.id)" -Body ($applicationJson | ConvertTo-Json -Depth 100) | Out-Null
    }

    if ($app.identifierUris) {
        $app.identifierUris = $app.identifierUris -replace '{{appId}}', $application.appId
        $uris = New-Object System.Collections.ArrayList
        $uris.Add($app.identifierUris) | Out-Null
        $patchBody = @{}
        $patchBody.Add("identifierUris", $uris)

        Write-Output "Updating Identifier Uris of '$($app.displayName)'"
        Invoke-RestMethod -Method Patch -Headers $headers -Uri "$applicationsUri/$($application.id)" -Body ($patchBody | ConvertTo-Json -Depth 100) | Out-Null
    }

    # Update the Permissions after app is created
    if ($app.selfApiPermission) {
        $resourceAccess = New-Object System.Collections.ArrayList
        $resource = New-Object psobject -property @{id = $application.api.oauth2PermissionScopes[0].id; type = "Scope" }
        $resourceAccess.Add($resource) | Out-Null

        $selfReference = New-Object psobject -property @{resourceAppId = $application.appId; resourceAccess = $resourceAccess }
        $requiredResourceAccess.Add($selfReference) | Out-Null

        $patchBody = @{}
        $patchBody.Add("requiredResourceAccess", $requiredResourceAccess)

        Write-Output "Updating Required Resource Access of '$($app.displayName)'"
        Invoke-RestMethod -Method Patch -Headers $headers -Uri "$applicationsUri/$($application.id)" -Body ($patchBody | ConvertTo-Json -Depth 100) | Out-Null
    }

    if ($app.groups) {
        foreach ($groupName in $app.groups) {
            Write-Output "Adding user groups to app reg. AppReg Name: '$($app.displayName)', User Group Name: '$($groupName)' "
            Add-ADGroupToAppReg -appName $app.displayName -groupName $groupName -graphApiVersion $GraphApiversion -headers $headers
        }
    }
}


function Add-ADGroupToAppReg() {

    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$appName,

        [Parameter(Mandatory = $True)]
        [string]$groupName,

        [Parameter(Mandatory = $True)]
        [string]$graphApiVersion,

        [Parameter(Mandatory = $false)]
        [Object]$headers = $null
    )


    $graphApiBaseUrl = "https://graph.microsoft.com"
    $servicePrincipalUri = "$graphApiBaseUrl/$graphApiVersion/servicePrincipals"
    $groupsUri = "$graphApiBaseUrl/$graphApiVersion/groups"

    $spUri = "$($servicePrincipalUri)?`$filter=(displayName eq '$($appName)')&`$select=id"
    $spId = (Invoke-RestMethod -Uri $spUri -Method GET -Headers $headers).value.id #resourceId


    $groupsUrl = "$($groupsUri)?`$filter=(displayName eq '$($groupName)')&`$select=id"
    $groupId = (Invoke-RestMethod -Uri $groupsUrl -Method GET -Headers $headers).value.id #principalId

    $spRoleUri = "$($servicePrincipalUri)/$spId/appRoleAssignedTo"
    $assignedGroups = (Invoke-RestMethod -Uri $spRoleUri -Method GET -Headers $headers).value
    
    if (-not($assignedGroups | Where-Object { $_.principalDisplayName  -eq $groupName })) {

        $postBody = @{
            principalId = $groupId
            resourceId  = $spId
        }
        
        $response = Invoke-RestMethod -Uri $spRoleUri -Method Post -Body ($postBody | ConvertTo-Json) -Headers $headers
    }

}

Function Add-AdAppRegistrations() {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$appsJsonFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$graphApiversion,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$tokenResource = "https://graph.microsoft.com",

        [Parameter(Mandatory = $false)]
        [Object]$headers = $null
    )

    $apps = (Get-Content $appsJsonFilePath -Raw) | ConvertFrom-Json

    if ($null -eq $headers) {
        Write-Verbose "Getting AccessToken for '$($tokenResource)'..."
        $token = (Get-AzAccessToken -Resource $tokenResource).Token

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Bearer $token")
    }

    foreach ($app in $apps.applications) {
        Add-Update-AadApp -app $app -graphApiVersion $GraphApiversion -headers $headers
    }
}
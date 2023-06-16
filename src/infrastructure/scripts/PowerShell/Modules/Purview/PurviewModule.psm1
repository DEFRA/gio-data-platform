function Invoke-PurviewRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$Method = 'GET',
       
        [object]$Body
    )

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
    }

    $requestParams = @{
        Uri          = $Url
        ContentType  = 'application/json'
        Headers      = $headers
        Method       = $Method
        UseBasicParsing = $true
    }

    if ($Body) {
        $requestParams.Body = $Body | ConvertTo-Json -Depth 100
    }

    Invoke-RestMethod @requestParams
}

function Get-PurviewCollections {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/account/collections?api-version=$ApiVersion"
   
    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url
}

function New-PurviewCollection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [string]$ParentCollectionName,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/collections/$($CollectionName)?api-version=$ApiVersion"

    $json = @{
        "parentCollection" = @{
            "referenceName" = "$ParentCollectionName"
        }
    }

    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url -Method 'PUT' -Body $json
}

function Get-PurviewPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/policyStore/metadataPolicies?api-version=$ApiVersion"

    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url
}

function Get-PurviewPolicyByCollectionName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/policyStore/metadataPolicies?collectionName=$($CollectionName)&api-version=$ApiVersion"

    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url
}

function Update-PurviewPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$PolicyId,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $url = "$($BaseUri)/policystore/metadataPolicies/$($PolicyId)?api-version=$ApiVersion"

    $policy = Get-PurviewPolicyByCollectionName -AccessToken $AccessToken -CollectionName $CollectionName -BaseUri $BaseUri -ApiVersion $ApiVersion

    $updatedPolicy = $policy.values[0]

    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url -Method 'PUT' -Body $updatedPolicy
}

function Add-PurviewPolicyRole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
     
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [psobject]$Policy,

        [Parameter(Mandatory = $true)]
        [psobject]$GroupId,

        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
       

    )

    $url = "$($BaseUri)/policystore/metadataPolicies/$($Policy.id)?api-version=$ApiVersion"

    $updatedPolicy = $Policy


    $permissionRule = $updatedPolicy.properties.attributeRules | Where-Object { $_.id -eq "permission:$CollectionName" }

    if ($permissionRule) {
        # Check if the permission rule contains an entry with the specified fromRule value
        $dnfCondition = $permissionRule.dnfCondition | Where-Object { $_.fromRule -eq "purviewmetadatarole_builtin_$($RoleName):$CollectionName" }
       
        if ($dnfCondition) {
            Write-Host "The specified condition exists in the attribute rule."
        } else {
            #CREATE THE DNF RULE
            $newCondition = [PSCustomObject]@{
                attributeName = "derived.purview.permission"
                attributeValueIncludes = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
                fromRule = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
            }
           
            $permissionRule.dnfCondition += , @($newCondition)

            Write-Host "The specified condition has been added to the attribute rule."

            #ADD THE NEW attribute as no dnf rule existed so must be a new one!
            #  $newAttr = [PSCustomObject]@{
            #     kind = "attributerule"
            #     id = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
            #     name = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
            #     dnfCondition = @(
            #         @(
            #             @{
            #                 fromRule = "purviewmetadatarole_builtin_$($RoleName)"
            #                 attributeName = "derived.purview.role"
            #                 attributeValueIncludes = "purviewmetadatarole_builtin_$($RoleName)"
            #             },
            #             @{
            #                 attributeName = "principal.microsoft.groups"
            #                 attributeValueIncludedIn = @($GroupId)
            #             }
            #         )
            #     )
            # }

            $dnfArray = @(
                [PSCustomObject]@{
                    fromRule = "purviewmetadatarole_builtin_$($RoleName)"
                    attributeName = "derived.purview.role"
                    attributeValueIncludes = "purviewmetadatarole_builtin_$($RoleName)"
                },
                [PSCustomObject]@{
                    attributeName = "principal.microsoft.groups"
                    attributeValueIncludedIn = @($GroupId)
                }
            )

            $newAttr = [PSCustomObject]@{
                kind = "attributerule"
                id = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
                name = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
                dnfCondition = ,@($dnfArray)
            }

             $updatedPolicy.properties.attributeRules += $newAttr  

        }
    } else {
        Write-Host "No attribute rule with ID 'permission:$CollectionName' exists."
    }
       
    #$output =  $updatedPolicy | ConvertTo-Json -Depth 100

    #Write-Host $output

    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url -Method 'PUT' -Body $updatedPolicy
}

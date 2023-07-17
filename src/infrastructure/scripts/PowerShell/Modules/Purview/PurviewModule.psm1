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

function Get-PurviewCollectionByName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $url = "$($BaseUri)/account/collections/$CollectionName?api-version=$ApiVersion"
   
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

    $systemInternalName = [regex]::Replace($CollectionName, "[^a-zA-Z0-9]", "")

    $url = "$($BaseUri)/account/collections/$($systemInternalName)?api-version=$ApiVersion"

    Write-Host "Pushing to" $url

    $json = @{
        "name" = "systemInternalName"
        "parentCollection" = @{
            "type" = "CollectionReference"
            "referenceName" = "$ParentCollectionName"
        }
        "friendlyName" = $CollectionName
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
        $dnfCondition = $updatedPolicy.properties.attributeRules | Where-Object { $_.id -eq "purviewmetadatarole_builtin_$($RoleName):$CollectionName" }
           
        if ($dnfCondition) 
        {           
            $dnfCondition.dnfCondition[0][1].attributeValueIncludedIn += $GroupId
        } else {
            #CREATE THE DNF RULE
            $newCondition = [PSCustomObject]@{
                attributeName = "derived.purview.permission"
                attributeValueIncludes = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
                fromRule = "purviewmetadatarole_builtin_$($RoleName):$CollectionName"
            }
           
            $permissionRule.dnfCondition += , @($newCondition)

            Write-Host "The specified condition has been added to the attribute rule."

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

function New-Classification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ClassificationName,

        [Parameter(Mandatory = $true)]
        [string]$ClassificationDescription,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/catalog/api/atlas/v2/types/typedefs?api-version=$ApiVersion"

      $json = @{
        classificationDefs = @(
            @{
                name = $ClassificationName
                description = $ClassificationDescription
            }
        )
    }
     
    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url -Method 'POST' -Body $json
}

function Get-Classification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ClassificationName,

        [Parameter(Mandatory = $true)]
        [string]$BaseUri
    )

    $url = "$($BaseUri)/catalog/api/atlas/v2/types/classificationdef/name/$ClassificationName"
     
    Invoke-PurviewRestMethod -AccessToken $AccessToken -Url $url -Method 'GET' -Body $json
}

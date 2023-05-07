function SignIn {
    param (
        [string] [Parameter(Mandatory=$true)] $SubscriptionName
    )

    if((az account show --query name --output tsv) -ne $SubscriptionName) {
        az login
        az account set --subscription $SubscriptionName
    }
}

function Get-Settings {
    param (
        [string] [Parameter(Mandatory=$true)] $fileName
    )

    $RootFolder = "$($PSScriptRoot)\..\..\"
    return Get-Content -Raw -Path ($RootFolder + "/settings/" + $fileName + ".json") | ConvertFrom-Json
}

function KeyVaultExists()
{
    param(
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $ResourceGroup
    )

    # Check if keyvault exists
    $count = az keyvault list -g $ResourceGroup --query "[?name=='$KeyVaultName'] | length(@)"
    return $count -gt 0
}

function CreateKeyVault()
{
    param(
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $ResourceGroup
    )

    $location = az group show --name $ResourceGroup --query "location"
    az keyvault create --name $KeyVaultName --resource-group $ResourceGroup --location $location
}

function KeyVaultSecretExists {
    param (
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $SecretName
    )

    $count = az keyvault secret list --vault-name $KeyVaultName --query "[?name=='$SecretName'] | length(@)"
    return $count -gt 0
}

function GetOrCreateKeyVaultSecret() {
    param (
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $SecretName
    )

    $exists = KeyVaultSecretExists -KeyVaultName $KeyVaultName -SecretName $SecretName

    if ($exists) {
        return az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "value"
    } else {
        $NewPassword = GeneratePassword -Length 16
        az keyvault secret set --vault-name $KeyVaultName --name $SecretName --value $NewPassword
        return $NewPassword
    }
}

function SetKeyVaultAccessPolicies()
{
    param (
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $ResourceGroup
    )

    $Query = "[].{Name: name, PrincipalId: identity.principalId}"
    $SlotQuery = "[].{Name: name, PrincipalId: identity.principalId}"

    $Identities = az webapp list --resource-group $ResourceGroup --query $Query | ConvertFrom-Json

    foreach ($id in $Identities) {
        SetKeyVaultPolicyForPrincipal -KeyVaultName $KeyVaultName -PrincipalId $id.PrincipalId -ResourceName $id.Name

        $SlotIdentities = az webapp deployment slot list --name $id.Name --resource-group $ResourceGroup --query $SlotQuery | ConvertFrom-Json

        foreach ($slotId in $SlotIdentities) {
            SetKeyVaultPolicyForPrincipal -KeyVaultName $KeyVaultName -PrincipalId $slotId.PrincipalId -ResourceName "$($id.Name)-$($slotId.Name)"
        }
    }

    $Identities = az functionapp list --resource-group $ResourceGroup --query $Query | ConvertFrom-Json

    foreach ($id in $Identities) {
        SetKeyVaultPolicyForPrincipal -KeyVaultName $KeyVaultName -PrincipalId $id.PrincipalId -ResourceName $id.Name

        $SlotIdentities = az functionapp deployment slot list --name $id.Name --resource-group $ResourceGroup --query $SlotQuery | ConvertFrom-Json

        foreach ($slotId in $SlotIdentities) {
            SetKeyVaultPolicyForPrincipal -KeyVaultName $KeyVaultName -PrincipalId $slotId.PrincipalId -ResourceName "$($id.Name)-$($slotId.Name)"
        }
    }

    $Identities = az apim list --resource-group $ResourceGroup --query $Query | ConvertFrom-Json

    foreach ($id in $Identities) {
        SetKeyVaultPolicyForPrincipal -KeyVaultName $KeyVaultName -PrincipalId $id.PrincipalId -ResourceName $id.Name
    }
}

function SetKeyVaultPolicyForPrincipal() {
    param (
        [Parameter(Mandatory=$True)]        
        [string]
        $KeyVaultName,

        [Parameter(Mandatory=$True)]        
        [string]
        $PrincipalId,

        [Parameter(Mandatory=$True)]        
        [string]
        $ResourceName
    )
    
    Write-Host "Setting access policy for $ResourceName"
    az keyvault set-policy -n $KeyVaultName --secret-permissions get list --object-id $PrincipalId --output none
}

function GeneratePassword()
{
    param (
        [int]
        $Length = 24,

        [switch]
        $IncludeSpecial
    )

    $CharSet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    if ($IncludeSpecial) {
        $CharSet = "!#$%*" + $CharSet;
    }

    return ($CharSet.ToCharArray() | Sort-Object {Get-Random})[0..$Length] -join '';
}

function Write-StartText {
    param (
        [string] [Parameter(Mandatory=$true)] $Text
    )

    Write-Host "--- $Text" -ForegroundColor Blue
}

function Write-StartProvisioning {
    param (
        [string] [Parameter(Mandatory=$true)] $Resource
    )

    Write-StartText "Provisioning $Resource"
}

function Write-Done {
    Write-Host "--- Done" -ForegroundColor Green
    Write-Host
}

function Get-DeploymentName {
    param (
        [string] [Parameter(Mandatory=$true)] $Name
    )

    return $Name + "-" + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm')
}
#Requires -Version 7.0

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# ASCII text: http://patorjk.com/software/taag/#p=display&f=Standard
# Error handling: https://rajbos.github.io/blog/2019/07/12/Azure-CLI-PowerShell

#    _____                 _   _                 
#   |  ___|   _ _ __   ___| |_(_) ___  _ __  ___ 
#   | |_ | | | | '_ \ / __| __| |/ _ \| '_ \/ __|
#   |  _|| |_| | | | | (__| |_| | (_) | | | \__ \
#   |_|   \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#                                                

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

#    ____             _             
#   |  _ \  ___ _ __ | | ___  _   _ 
#   | | | |/ _ \ '_ \| |/ _ \| | | |
#   | |_| |  __/ |_) | | (_) | |_| |
#   |____/ \___| .__/|_|\___/ \__, |
#              |_|            |___/ 

$Settings = Get-Settings "commercetools"

Write-StartText "Signing in to '$($Settings.Subscription)'"
SignIn $Settings.Subscription
Write-Done

Write-StartText "Initializing keyvault"
$KeyVaultExists = KeyVaultExists -KeyVaultName $Settings.KeyVaultName -ResourceGroup $Settings.ResourceGroup

if (!$KeyVaultExists) {
    Write-Host "Creating keyvault $($Settings.KeyVaultName)"
    CreateKeyVault -KeyVaultName $Settings.KeyVaultName -ResourceGroup $Settings.ResourceGroup
} else {
    Write-Host "Keyvault $($Settings.KeyVaultName) already exists"
}

Write-StartProvisioning "commercetools resources"
$DeploymentName = Get-DeploymentName "commercetools"
az deployment group create `
    --name $DeploymentName `
    --resource-group $Settings.ResourceGroup `
    --template-file "$($PSScriptRoot)/../templates/commercetools.bicep" `
    --parameters "@$($PSScriptRoot)/../settings/parameters-commercetools.json" `
    --parameters "@$($PSScriptRoot)/../settings/$($Settings.Parameters)" `
    --parameters keyVaultName=$($Settings.KeyVaultName) applicationId=$($Settings.ApplicationId) cloud_name=$($Settings.cloud_name) cloud_api_key=$($Settings.cloud_api_key) cloud_api_secret=$($Settings.cloud_api_secret) property_sku=$($Settings.property_sku) property_publish=$($Settings.property_publish) property_sort=$($Settings.property_sort) ct_asset_type_key=$($Settings.ct_asset_type_key) ct_property_sort=$($Settings.ct_property_sort) authUrl=$($Settings.authUrl) clientId=$($Settings.clientId) clientSecret=$($Settings.clientSecret) apiUrl=$($Settings.apiUrl) projectKey=$($Settings.projectKey)
Write-Done

Write-StartText "Configuring keyvault access policies"
SetKeyVaultAccessPolicies -KeyVaultName $Settings.KeyVaultName -ResourceGroup $Settings.ResourceGroup 
Write-Done

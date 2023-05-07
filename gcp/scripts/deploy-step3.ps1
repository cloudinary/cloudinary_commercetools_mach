Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"


Write-StartText "Enabling Secret Manager for project $($Settings.ProjectId)"
EnableSecretManager

Write-StartText "Configuring Secret Manager"
SetupSecretManagerSA -ProjectId $Settings.ProjectId -SecretAccessorSAName $Settings.SecretAccessorSAName -AppName $Settings.CloudRunSubscriberName

CreateSecret -SecretId cloud-api-secret
CreateSecret -SecretId ct-client-secret

CreateSecretVersion -SecretId cloud-api-secret -SecretValue "$($Settings.cloud_api_secret)"
CreateSecretVersion -SecretId ct-client-secret -SecretValue "$($Settings.clientSecret)"

AssignSASecretAccess -ProjectId $Settings.ProjectId -SecretAccessorSAName $Settings.SecretAccessorSAName -SecretId cloud-api-secret
AssignSASecretAccess -ProjectId $Settings.ProjectId -SecretAccessorSAName $Settings.SecretAccessorSAName -SecretId ct-client-secret

AssignSASecretAccess -ProjectId $Settings.ProjectId -SecretAccessorSAName $Settings.PubsubInvokerSAName -SecretId cloud-api-secret
AssignSASecretAccess -ProjectId $Settings.ProjectId -SecretAccessorSAName $Settings.PubsubInvokerSAName -SecretId ct-client-secret

Write-Done
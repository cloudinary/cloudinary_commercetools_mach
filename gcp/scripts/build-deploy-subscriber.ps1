Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$parentDir = Split-Path $dir
Write-host "Changing directory to $parentDir\cloudinary-pubsub-scubscriber"
Set-Location -Path "$parentDir\cloudinary-pubsub-scubscriber"

Write-StartText "Building PUB/SUB subscriber container"
BuildContainer -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunSubscriberName

Write-StartText "Deploying PUB/SUB subscriber application"
DeployApp -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunSubscriberName -RequireAuth $True -EnvVars "^@^GOOGLE_CLOUD_PROJECT_ID=$($Settings.ProjectId)@GOOGLE_CLOUD_TOPIC=$($Settings.Topic)@cloud_name=$($Settings.cloud_name)@cloud_api_key=$($Settings.cloud_api_key)@authUrl=$($Settings.authUrl)@clientId=$($Settings.clientId)@apiUrl=$($Settings.apiUrl)@projectKey=$($Settings.projectKey)@property_sku=$($Settings.property_sku)@property_publish=$($Settings.property_publish)@property_sort=$($Settings.property_sort)"
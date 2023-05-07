Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$parentDir = Split-Path $dir
Write-host "Changing directory to $parentDir\cloudinary-notification"
Set-Location -Path "$parentDir\cloudinary-notification"

Write-StartText "Building public API container"
BuildContainer -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunName

Write-StartText "Deploying public API application"
DeployApp -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunName -RequireAuth $True -EnvVars "^@^GOOGLE_CLOUD_PROJECT_ID=$($Settings.ProjectId)@GOOGLE_CLOUD_TOPIC=$($Settings.Topic)"
Write-Done

# https://cloud.google.com/build/docs/automating-builds/create-manage-triggers#gcloud
# https://cloud.google.com/build/docs/deploying-builds/deploy-cloud-run

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             
Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$parentDir = Split-Path $dir
$buildTemplPathPub = "$parentDir\cloudinary-notification\cloudbuild.yaml"
$buildTemplPathSub = "$parentDir\cloudinary-pubsub-scubscriber\cloudbuild.yaml"

Write-StartText "Creating build template for $($Settings.CloudRunName)"
CreateContinuousDeploymentTempl -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunName -Region $Settings.Region -TemplPath $buildTemplPathPub

Write-StartText "Creating build template for $($Settings.CloudRunSubscriberName)"
CreateContinuousDeploymentTempl -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunSubscriberName -Region $Settings.Region -TemplPath $buildTemplPathSub

# TODO: refactor the code to have cloudbuild templates in the root of each app

Write-StartText "Creating build trigger for $($Settings.CloudRunName)"
CreateBuildTrigger -RepositoryOwner $Settings.RepositoryOwner -Repository $Settings.Repository -Region $Settings.Region -Branch $Settings.Branch -TemplPath $buildTemplPathPub
Write-Done

Write-StartText "Creating build trigger for $($Settings.CloudRunSubscriberName)"
CreateBuildTrigger -RepositoryOwner $Settings.RepositoryOwner -Repository $Settings.Repository -Region $Settings.Region -Branch $Settings.Branch -TemplPath $buildTemplPathSub
Write-Done
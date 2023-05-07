Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"

powershell -executionpolicy bypass "$($PSScriptRoot)\build-deploy-subscriber.ps1" 

Write-StartText "Enabling Pub/Sub for project $($Settings.ProjectId)"
EnablePubSub

Write-StartText "Configuring Pub/sub"
SetupPubSub -ProjectId $Settings.ProjectId -Region $Settings.Region -Topic $Settings.Topic -PubsubInvokerSAName $Settings.PubsubInvokerSAName -AppName $Settings.CloudRunSubscriberName -PubsubSubscription $Settings.PubsubSubscription
Write-Done

powershell -executionpolicy bypass "$($PSScriptRoot)\build-deploy-publisher.ps1" 

Write-StartText "Setting up service accounts"
SetupPublisherSA -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunName -PubsubPublisherSAName $Settings.PubsubPublisherSAName -Topic $Settings.Topic
Write-Done
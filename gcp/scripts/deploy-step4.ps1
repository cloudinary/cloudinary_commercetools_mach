Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"


Write-StartText "Enabling Api Gateway for project $($Settings.ProjectId)"
EnableApiGateway

Write-StartText "Configuring Api Gateway"
SetupApiGatewaySA -ProjectId $Settings.ProjectId -AppName $Settings.CloudRunName -ApiGatewaySAName $Settings.ApiGatewaySAName

SetupApiGateway -ProjectId $Settings.ProjectId -Region $Settings.Region -AppName $Settings.CloudRunName -ApiGatewaySAName $Settings.ApiGatewaySAName -OpenApiSpec openapi2-run.yaml -ApiGatewayConfigId $Settings.ApiGatewayConfigId -ApiGatewayId $Settings.ApiGatewayId 
Write-Done
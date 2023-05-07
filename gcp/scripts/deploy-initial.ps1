Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
                                             

Import-Module "$($PSScriptRoot)\utils\functions.psm1" -Force

$Settings = Get-Settings "commercetools"

SignIn

UpdateComponents

$ProjectExists = ProjectExists -ProjectId $Settings.ProjectId

if (!$ProjectExists) {
    Write-StartText "Creating project"

    CreateProject -ProjectId $Settings.ProjectId -ProjectName $Settings.ProjectId -OrganizationId $Settings.OrganizationId
    $ProjectCreated = ProjectExists -ProjectId $Settings.ProjectId

    if ($ProjectCreated) {
        SetDefaults -ProjectId $Settings.ProjectId -Region $Settings.Region
    }

    Write-Done
}
else {
    Write-Host "Project $($Settings.ProjectId) already exists"

    SetDefaults -ProjectId $Settings.ProjectId -Region $Settings.Region
}

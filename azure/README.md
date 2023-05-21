# commercetools Cloudinary MACH integration on Azure

These instructions walk you through configuring Microsoft Azure to host the serverless microservice that integrates Cloudinary assets in your commercetools instance.

## Installation
See [Azure installation documentation](https://cloudinary.com/documentation/commercetools_installation#microsoft_azure).

### Next steps

# AZURE resources config

Update settings/commercetools.json

## Azure
* Subscription : the name of the Azure Subscription where resources will be deployed
* ResourceGroup : the name of the AZure ResourceGroup where resouces will be deployed
* KeyVaultName : the desired name for the KeyVault
* ApplicationId : the desired name for the application (resources will be named e.g. "apim-<applicationId>", "func-<applicationId>", ...)

## Cloudinary

* cloud_name : the name of your Cloudinary instance
* cloud_api_key : the apiKey for your Cloudinary instance
* cloud_api_secret : the apiSecret for your Cloudinary instance
* property_sku : the name of the Cloudinary property you've chosen to contains the CommerceTools SKU

## CommerceTools

You will get all the values below when you create a new API key in CommerceTools.

* authUrl : CommerceTools' authUrl (e.g. https://auth.us-central1.gcp.commercetools.com)
* clientId : CommerceTools' clientId
* clientSecret : CommerceTools' clientSecret
* apiUrl : CommerceTools' apiUrl (e.g. https://api.us-central1.gcp.commercetools.com)
* projectKey :  : CommerceTools' projectKey

# Powershell deployment scripts

* `scripts\deploy-step1.ps1`
* Deploy function (e.g. using VS Code extension)
* `scripts\deploy-step2.ps1`

> If the script shows the error "The user, group or application 'name=Microsoft.ApiManagement/service;appid=<guid>;oid=<guid>;iss=https://sts.windows.net/<guid>/' does not have secrets get permission on key vault '...'." this is caused by one or more access policy that aren't ready yet.
> Try to re-deploy again after a gew minutes so Azure finishes creating the required resources

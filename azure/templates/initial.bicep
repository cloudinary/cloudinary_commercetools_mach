//    ____                               
//   |  _ \ __ _ _ __ __ _ _ __ ___  ___ 
//   | |_) / _` | '__/ _` | '_ ` _ \/ __|
//   |  __/ (_| | | | (_| | | | | | \__ \
//   |_|   \__,_|_|  \__,_|_| |_| |_|___/
//

param logRetentionInDays int = 30

param applicationId string

param functionApps array

@minLength(1)
param keyVaultName string

param cloud_name string
param cloud_api_key string
@secure()
param cloud_api_secret string
param property_sku string
param property_publish string
param property_sort string

param ct_asset_type_key string
param ct_property_sort string

param authUrl string
param clientId string
@secure()
param clientSecret string
param apiUrl string
param projectKey string

param location string = resourceGroup().location

param apimApis array
param apimApisOperations array
param apimProducts array
param apimProductApis array
param apimSubscriptions array

param serviceBusQueues array

//   __     __             
//   \ \   / /_ _ _ __ ___ 
//    \ \ / / _` | '__/ __|
//     \ V / (_| | |  \__ \
//      \_/ \__,_|_|  |___/
//

var apiAppPlanName = 'plan-${applicationId}-apis'

var apimName = 'apim-${applicationId}'
var storageAccountName = 'st${applicationId}'

var appInsightsName = 'appi-${applicationId}'

var functionNames = [for item in functionApps: 'func-${applicationId}-${item.name}']

var serviceBusName = 'sb-${applicationId}'

var azureUrl = 'management'

//    ____                                         
//   |  _ \ ___  ___  ___  _   _ _ __ ___ ___  ___ 
//   | |_) / _ \/ __|/ _ \| | | | '__/ __/ _ \/ __|
//   |  _ <  __/\__ \ (_) | |_| | | | (_|  __/\__ \
//   |_| \_\___||___/\___/ \__,_|_|  \___\___||___/
//

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: apiAppPlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'S1'
  }
  properties: {
    reserved: true
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: logRetentionInDays
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = [for queueName in serviceBusQueues: {
  name: queueName
  parent: serviceBus
}]

resource functionNamesApp 'Microsoft.Web/sites@2021-03-01' = [for functionName in functionNames: {
  name: functionName
  kind: 'functionapp,linux'
  location: location
  dependsOn: [
    // keyVaultAppConfig
  ]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
    reserved: true
    siteConfig: {
      linuxFxVersion: 'NODE|18'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
        {
          name: 'vaultName'
          value: keyVaultName
        }
        {
          name: 'cloud_name'
          value: cloud_name
        }
        {
          name: 'cloud_api_key'
          value: cloud_api_key
        }
        {
          name: 'property_sku'
          value: property_sku
        }
        {
          name: 'property_publish'
          value: property_publish
        }
        {
          name: 'property_sort'
          value: property_sort
        }
        {
          name: 'ct_asset_type_key'
          value: ct_asset_type_key
        }
        {
          name: 'ct_property_sort'
          value: ct_property_sort
        }
        {
          name: 'authUrl'
          value: authUrl
        }
        {
          name: 'clientId'
          value: clientId
        }
        {
          name: 'apiUrl'
          value: apiUrl
        }
        {
          name: 'projectKey'
          value: projectKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'cloudinaryct_SERVICEBUS'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/servicebus-connectionstring/)'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${storageAccount.name}314'
        }
        {
          name: 'WEBSITE_ENABLE_SYNC_UPDATE_SITE'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  scope: resourceGroup()
  name: keyVaultName
}

resource keyVaultServiceBus 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'servicebus-connectionstring'
  properties: {
    value: 'Endpoint=sb://${serviceBus.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys('${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBus.apiVersion).primaryKey}'
  }
}

resource keyVaultClientSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'ct-client-secret'
  properties: {
    value: clientSecret
  }
}

resource keyVaultCloudSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'cloud-api-secret'
  properties: {
    value: cloud_api_secret
  }
}

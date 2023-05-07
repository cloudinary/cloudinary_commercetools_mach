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

resource keyVaultApimPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        objectId: apim.identity.principalId
        tenantId: apim.identity.tenantId
        permissions: {
          keys: []
          secrets: [
            'list'
            'get'
          ]
          certificates: []
        }
      }
    ]
  }
}

resource keyVaultFunctionSecrets 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for functionName in functionNames: {
  parent: keyVault
  name: '${functionName}-key'
  dependsOn: [
    functionNamesApp
  ]
  properties: {
    value: listKeys('${resourceId('Microsoft.Web/sites', functionName)}/host/default', '2021-03-01').functionKeys.default
  }
}]

// resource keyVaultAppConfig 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
//   parent: keyVault
//   name: 'appconfiguration-connectionstring'
//   properties: {
//     value: appConfig.listKeys().value[0].connectionString
//   }
// }

resource keyVaultServiceBus 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'servicebus-connectionstring'
  dependsOn: [
    serviceBus
  ]
  properties: {
    value: 'Endpoint=sb://${serviceBus.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys('${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBus.apiVersion).primaryKey}'
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    capacity: 0
    name: 'Consumption'
  }
  properties: {
    publisherEmail: 'developers@reference.be'
    publisherName: 'The Reference'
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${apimName}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
        certificateSource: 'BuiltIn'
      }
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'False'
    }
    virtualNetworkType: 'None'
    enableClientCertificate: false
    disableGateway: false
    apiVersionConstraint: {}
    publicNetworkAccess: 'Enabled'
  }
}

resource apimNamedValuesFunc 'Microsoft.ApiManagement/service/namedValues@2021-12-01-preview' = [for functionName in functionNames: {
  name: '${functionName}-key'
  parent: apim
  dependsOn: [
    keyVaultFunctionSecrets
  ]
  properties: {
    displayName: '${functionName}-key'
    tags: [
      'key'
      'function'
      'auto'
    ]
    secret: true
    keyVault: {
      secretIdentifier: '${keyVault.properties.vaultUri}secrets/${functionName}-key'
    }
  }
}]

resource apimFuncBackends 'Microsoft.ApiManagement/service/backends@2021-12-01-preview' = [for functionName in functionNames: {
  name: functionName
  parent: apim
  dependsOn: [
    apimNamedValuesFunc
  ]
  properties: {
    description: functionName
    url: 'https://${functionName}.azurewebsites.net/api'
    resourceId: 'https://${azureUrl}.azure.com/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionName}'
    protocol: 'http'
    credentials: {
      header: {
        'x-functions-key': [
          '{{${functionName}-key}}'
        ]
      }
    }
  }
}]

resource apimApi 'Microsoft.ApiManagement/service/apis@2021-12-01-preview' = [for api in apimApis: {
  name: api.name
  parent: apim
  dependsOn: [
    // apimAppBackends
    apimFuncBackends
    // apimNamedValuesAdditional
    apimNamedValuesFunc
  ]
  properties: {
    displayName: api.displayName
    path: api.path
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}]

resource apimApiOperation 'Microsoft.ApiManagement/service/apis/operations@2021-12-01-preview' = [for operation in apimApisOperations: {
  name: '${apim.name}/${operation.apiName}/${operation.method}-${operation.displayName}'
  dependsOn: [
    apimApi
  ]
  properties: {
    displayName: operation.displayName
    method: operation.method
    request: {
      queryParameters: operation.queryParameters
      representations: operation.representations
    }
    urlTemplate: operation.url
    templateParameters: operation.templateParameters
    responses: operation.responses
  }
}]

resource apimPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2021-12-01-preview' = [for operation in apimApisOperations: {
  name: '${apimName}/${operation.apiName}/${operation.method}-${operation.displayName}/policy'
  dependsOn: [
    apimApiOperation
  ]
  properties: {
    format: 'rawxml'
    value: replace(operation.policies, '[BACKENDID]', '${operation.urlPrefix}-${applicationId}-${operation.path}')
  }
}]

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: appInsights.name
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsights.id
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
  }
}

resource apimProduct 'Microsoft.ApiManagement/service/products@2021-12-01-preview' = [for item in apimProducts: {
  name: item.name
  parent: apim
  dependsOn: [
    apimApi
  ]
  properties: {
    displayName: item.displayName
    description: item.description
    state: 'published'
    subscriptionRequired: true
  }
}]

resource apimProductApi 'Microsoft.ApiManagement/service/products/apis@2021-12-01-preview' = [for item in apimProductApis: {
  name: '${apim.name}/${item.product}/${item.api}'
  dependsOn: [
    apimProduct
  ]
}]

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-12-01-preview' = [for item in apimSubscriptions: {
  name: item.name
  parent: apim
  dependsOn: [
    apimProduct
  ]
  properties: {
    displayName: item.displayName
    scope: (empty(item.product) ? '/apis' : 'products/${resourceId('Microsoft.ApiManagement/service/products', apim.name, item.product)}')
    allowTracing: true
    state: 'active'
  }
}]

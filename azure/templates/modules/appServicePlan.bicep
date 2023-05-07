@minLength(1)
param name string

@minLength(1)
@allowed([
  'app'
  'linux'
  'functionapp'
])
param kind string

@minLength(1)
param sku string

@minLength(1)
param location string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: name
  location: location
  kind: kind
  sku: {
    name: sku
  }
  properties: {
    reserved: kind == 'linux' ? true : false
  }
}

output id string = appServicePlan.id

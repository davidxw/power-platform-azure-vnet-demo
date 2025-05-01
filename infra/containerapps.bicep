// Createe a storage account with a private endpoint in the primary VNet.
// Also creates private DNS zone for blob storage, connected to both VNets.

@description('The base name to be used for all resources.')
param baseName string = 'pp-test'

@description('The location for the resources.')
param location string = 'eastus'

param primaryVnetName string = 'pp-vnet'
param secondaryVnetName string = 'pp-vnet-secondary'

@description('The name of the container app.')
param containerAppName string = '${baseName}-ca'

@description('The image to use for the container app.')
param containerImage string = 'davidxw/webtest:latest'

var containerAppSubnetName = 'containerapp-subnet'
var privateEndpointSubnetAddressRange = '10.0.2.0/24'

resource primaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: primaryVnetName
}

resource containerAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: containerAppSubnetName
  parent: primaryVnet
  properties: {
    addressPrefix: privateEndpointSubnetAddressRange
    delegations: [
      {
        name: '0'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

// Log Analytics workspace
resource wxacatestprofilesla 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  location: location
  name: '${baseName}-la'
}

// Internal ACA environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${baseName}-aca-env'
  location: location
  properties: {
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: containerAppSubnet.id
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: wxacatestprofilesla.properties.customerId
        sharedKey: wxacatestprofilesla.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

resource containerApp_noauth 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppName}-noauth'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource containerApp_auth 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppName}-auth'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource containerApp_auth_config 'Microsoft.App/containerApps/authConfigs@2025-01-01' = {
  parent: containerApp_auth
  name: 'current'
  properties: {
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        isAutoProvisioned: true
      }
    }
  }
}

module privateDnsZoneModule 'privatedns.bicep' = {
  name: 'privateDnsZoneModule'
  params: {
    privateDnsZoneName: containerAppEnvironment.properties.defaultDomain
    primaryVnetName: primaryVnetName
    secondaryVnetName: secondaryVnetName
    aRecordIps: [
      containerAppEnvironment.properties.staticIp
    ]
  }
}

output containerNoauthAppFQDN string = containerApp_noauth.properties.configuration.ingress.fqdn
output containerAppAuthFQDN string = containerApp_auth.properties.configuration.ingress.fqdn





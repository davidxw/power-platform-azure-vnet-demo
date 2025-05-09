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

var containerApp_noauth_name = '${containerAppName}-noauth'
var containerApp_auth_name = '${containerAppName}-auth'

var appSecretSettingName = 'microsoft-provider-authentication-secret'

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

var container_template = {
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

var container_ingress ={
  external: true
  targetPort: 8080
}

resource containerApp_noauth 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerApp_noauth_name
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: container_ingress
    }
    template: container_template
  }
}

resource containerApp_auth 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerApp_auth_name
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: container_ingress
      secrets: [
        {
          name: appSecretSettingName
          value: entra_app.outputs.app_client_secret
        }
      ]
    }
    template: container_template
  }
}

var containerApp_auth_fqdn = '${containerApp_auth_name}.${containerAppEnvironment.properties.defaultDomain}'

// Create an Entra application for the container app authentication
module entra_app 'entra_application.bicep' = {
  name: 'entra_app'
  params: {
    service_name: containerApp_auth_name
    service_fqdn: containerApp_auth_fqdn
  }
}

resource containerApp_auth_config 'Microsoft.App/containerApps/authConfigs@2025-01-01' = {
  parent: containerApp_auth
  name: 'current'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'Return401'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        isAutoProvisioned: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientId: entra_app.outputs.appId
          clientSecretSettingName: appSecretSettingName
        }
        login: {
          disableWWWAuthenticate: false
        }
        validation: {
          jwtClaimChecks: {}
          allowedAudiences: [
              'api://${containerApp_auth_fqdn}'
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {}
          }
        }
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
output containerAppAuthAppId string = entra_app.outputs.appId





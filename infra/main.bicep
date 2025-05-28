@description('The base name to be used for all resources.')
param baseName string

@description('The location of your Power Platform environment.')
param geoLocation string = 'unitedstates'

@description('The primary location for the Azure resources resources. Should align with your Power Platform environment location as per this list: https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview#supported-regions.')
param primaryLocation string = 'eastus'

@description('The secondary location for the Azure resources resources. Required for Power Platform regions that support two Azure regions (as per the link above). Set to an empty string if there is only one Azure region for your Power Platform region.')
param secondaryLocation string = 'westus'

@description('The name of the subnet that will be delegated to your Power Platform enterprise poilicy.')
param subnetName string = 'powerplatform'

@description('Polices that are linked to Power Platform environments cannot be updates - set to false if the policy exists')
param createPolicy bool = true

@description('The address space for the virtual network in the primary location.')
var vnetAddressSpacePrimary = '10.0.0.0/16'

@description('The address space for the virtual network in the primary location. Not used for single-region deployments.')
var vnetAddressSpaceSecondary = '10.1.0.0/16'

@description('The address range for the primary powerplatform subnet.')
param ppSubnetAddressRangePrimary string = '10.0.0.0/24'

@description('The address range for the secondary powerplatform subnet. Not used for single-region deployments.')
param ppSubnetAddressRangeSecondary string = '10.1.0.0/24'

@description('The name of the subnet for private endpoints. This is used by the blog storage modeule ')
param privateEndpointSubnetName string = 'private-endpoints'

@description('The address range for the private endpoint subnet.')
param privateEndpointSubnetAddressRange string = '10.0.1.0/24'

@description('The name of the subnet for container apps. This is used by the container apps module.')
param containerAppSubnetName string = 'containerapp-subnet'

@description('The address range for the container app subnet.')
param containerAppSubnetAddressRange string = '10.0.2.0/24'

@description('Set to true if you want to create test resources such as a blob storage account and container apps. These are not required for the Power Platform VNet integration, but are useful for testing custom connectors and the Entra ID connector.')
param createTestResources bool = true

var isSecondaryLocation = secondaryLocation != ''

var primaryVnetName = '${baseName}-${primaryLocation}-vnet'
var secondaryVnetName = (isSecondaryLocation) ? '${baseName}-${secondaryLocation}-vnet' : ''

var primaryLocations = [
  {
    location: primaryLocation
    addressSpace: vnetAddressSpacePrimary
    subnetAddressRange: ppSubnetAddressRangePrimary
  }
]

var secondaryLocations = [
  {
    location: secondaryLocation
    addressSpace: vnetAddressSpaceSecondary
    subnetAddressRange: ppSubnetAddressRangeSecondary
  }
]

var locations = (isSecondaryLocation) ? union(primaryLocations, secondaryLocations) : primaryLocations

// create the virtual networks and all subnets for the primary and secondary location (if specified)

module vnets 'powerPlatformIntegration/vnets.bicep' = {
  name: 'vnets'
  params: {
    locationObjects: locations
    baseName: baseName
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetAddressRange: privateEndpointSubnetAddressRange
    containerAppSubnetName: containerAppSubnetName
    containerAppSubnetAddressRange: containerAppSubnetAddressRange
  }
}

// Create the Power Platform enterprise policy for network injection. This is required for Power Platform to work with private endpoints.

resource enterprisePolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview' = if (createPolicy) {
  name: '${baseName}-policy'
  location: geoLocation
  kind: 'NetworkInjection'
  properties: {
    networkInjection: {
      virtualNetworks: [
        for locationObject in locations: {
          id: resourceId('Microsoft.Network/virtualNetworks', '${baseName}-${locationObject.location}-vnet')
          subnet: {
            name: subnetName
          }
        }
      ]
    }
  }
  dependsOn: [
    vnets
  ]
}

// Create a blob storage account with private endpoints and a container for files. This is only required if you want to test VNet integration with your Power Platform environment.

module blob 'testResources/storage.bicep' = if (createTestResources) {
  name: 'blob'
  params: {
    baseName: baseName
    location: primaryLocation
    primaryVnetName: primaryVnetName
    secondaryVnetName: secondaryVnetName
    privateEndpointSubnetName: privateEndpointSubnetName
  }
  dependsOn: [
    vnets
  ]
}

// Create container apps with a test API. This is only required if you want to test custom connectos or the Entra ID connector with your Power Platform environment.

module containerApp 'testResources/containerapps.bicep' = if (createTestResources) {
  name: 'containerApp'
  params: {
    baseName: baseName
    location: primaryLocation
    primaryVnetName: primaryVnetName
    secondaryVnetName: secondaryVnetName
  }
  dependsOn: [
    vnets
  ]
}

output policyArmId string = enterprisePolicy.id
output containerAppNoauthFQDN string = (createTestResources) ? containerApp.outputs.containerNoauthAppFQDN : ''
output containerAppauthFQDN string = (createTestResources) ? containerApp.outputs.containerAppAuthFQDN : ''
output containerAppAuthAppId string = (createTestResources) ? containerApp.outputs.containerAppAuthAppId : ''
output blobServiceEndpoint string = (createTestResources) ? blob.outputs.blobServiceEndpoint : ''

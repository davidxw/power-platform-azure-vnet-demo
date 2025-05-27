@description('The base name to be used for all resources.')
param baseName string

param geoLocation string = 'sweden'

param primaryLocation string = 'swedencentral'
param secondaryLocation string = ''

param subnetName string = 'powerplatform'

@description('Polices that are linked to Power Platform environments cannot be updates - set to false if the policy exists')
param createPolicy bool = true

@description('The address space for the virtual network in the primary location.')
var vnetAddressSpacePrimary = '10.0.0.0/16'

@description('The address space for the virtual network in the primary location.')
var vnetAddressSpaceSecondary = '10.1.0.0/16'

@description('The address range for the "powerplatform" subnet.')
var ppSubnetAddressRangePrimary = '10.0.0.0/24'

@description('The address range for the "powerplatform" subnet.')
var ppSubnetAddressRangeSecondary = '10.1.0.0/24'

var isSecondaryLocation = secondaryLocation != ''

var primaryVnetName = '${baseName}-${primaryLocation}-vnet'
var secondaryVnetName = (isSecondaryLocation) ? '${baseName}-${secondaryLocation}-vnet' : ''

//var resourceToken = toLower(uniqueString(subscription().id, baseName, primaryLocation))

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

module vnets 'vnets.bicep' = {
  name: 'vnets'
  params: {
    locationObjects: locations
    baseName: baseName
  }
}

resource enterprisePolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview' = if (createPolicy) {
  name: '${baseName}-policy'
  location: geoLocation
  kind: 'NetworkInjection'
  properties: {
    networkInjection: {
      virtualNetworks: [
        for locationObject in locations: {
          id: resourceId('Microsoft.Network/virtualNetworks', '${baseName}-${locationObject.location}')
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

module blob 'storage.bicep' = {
  name: 'blob'
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

module containerApp 'containerapps.bicep' = {
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
output containerAppNoauthFQDN string = containerApp.outputs.containerNoauthAppFQDN
output containerAppauthFQDN string = containerApp.outputs.containerAppAuthFQDN
output containerAppAuthAppId string = containerApp.outputs.containerAppAuthAppId
output blobServiceEndpoint string = blob.outputs.blobServiceEndpoint

@description('The base name to be used for all resources.')
param baseName string = 'pp-test2'

param geoLocation string = 'unitedstates'

param primaryLocation string = 'eastus'
param secondaryLocation string = 'westus'

param subnetName string = 'pp'

@description('Polices that are linked to Power Platform environments cannot be updates - set to false if the policy exists')
param createPolicy bool = true

@description('The address space for the virtual network in the primary location.')
var vnetAddressSpacePrimary = '10.0.0.0/16'

@description('The address space for the virtual network in the primary location.')
var vnetAddressSpaceSecondary = '10.1.0.0/16'

@description('The address range for the "pp" subnet.')
var ppSubnetAddressRangePrimary = '10.0.0.0/24'

@description('The address range for the "pp" subnet.')
var ppSubnetAddressRangeSecondary = '10.1.0.0/24'

var resourceToken = toLower(uniqueString(subscription().id, baseName, primaryLocation))

var locations = [
  { 
    location: primaryLocation
    addressSpace: vnetAddressSpacePrimary
    subnetAddressRange: ppSubnetAddressRangePrimary
  }
  { 
    location: secondaryLocation
    addressSpace: vnetAddressSpaceSecondary
    subnetAddressRange: ppSubnetAddressRangeSecondary
  }
]

resource publicIPs 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for location in locations: {
  name: '${baseName}-${location.location}-pip'
  location: location.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource natGateways 'Microsoft.Network/natGateways@2021-05-01' = [for location in locations: {
  name: '${baseName}-${location.location}-nat'
  location: location.location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: resourceId('Microsoft.Network/publicIPAddresses', '${baseName}-${location.location}-pip')
      }
    ]
  }
  dependsOn: [
    publicIPs[0]
    publicIPs[1]
  ]
}]

resource vnets 'Microsoft.Network/virtualNetworks@2021-05-01' = [for location in locations: {
  name: '${baseName}-${location.location}'
  location: location.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        location.addressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: location.subnetAddressRange
          delegations: [
            {
              name: 'ppDelegation'
              properties: {
                serviceName: 'Microsoft.PowerPlatform/enterprisePolicies'
              }
            }
          ]
          natGateway: {
            id: resourceId('Microsoft.Network/natGateways', '${baseName}-${location.location}-nat')
          }
        }
      }
    ]
  }
  dependsOn: [
    natGateways[0]
    natGateways[1]
  ]
}]

resource primaryToSecondaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${vnets[0].name}-To-${vnets[1].name}'
  parent: vnets[0]
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    remoteVirtualNetwork: {
      id: vnets[1].id
    }
  }
  dependsOn: [
    vnets[0]
    vnets[1]
  ]
}

resource secondaryToPrimaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${vnets[1].name}-To-${vnets[0].name}'
  parent: vnets[1]
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    remoteVirtualNetwork: {
      id: vnets[0].id
    }
  }
  dependsOn: [
    vnets[0]
    vnets[1]
  ]
}

resource enterprisePolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview' = if (createPolicy) {
  name: '${baseName}-policy'
  location: geoLocation
  kind: 'NetworkInjection'
  properties: {
    networkInjection: {
      virtualNetworks: [for location in locations: {
          id: resourceId('Microsoft.Network/virtualNetworks', '${baseName}-${location.location}')
          subnet: {
            name: subnetName
          }
        }
      ]
    }
  }
  dependsOn: [
    vnets[0]
    vnets[1]
  ]
}

module blob 'storage.bicep' = {
  name: 'blob'
  params: {
    baseName: baseName
    location: vnets[0].location
    primaryVnetName: vnets[0].name
    secondaryVnetName: vnets[1].name
  }
  dependsOn: [
    vnets[0]
    vnets[1]
  ]
}

module containerApp1 'containerapp.bicep' = {
  name: 'containerApp'
  params: {
    baseName: baseName
    location: vnets[0].location
    primaryVnetName: vnets[0].name
    secondaryVnetName: vnets[1].name
  }
  dependsOn: [
    vnets[0]
    vnets[1]
  ]
}

// module containerApp1 'containerapp.bicep' = {
//   name: 'containerApp'
//   params: {
//     baseName: baseName
//     location: primaryLocation
//     primaryVnetName: '${baseName}-${primaryLocation}'
//     secondaryVnetName: '${baseName}-${secondaryLocation}'
//   }
// }

output containerAppFQDN string = containerApp1.outputs.containerAppFQDN



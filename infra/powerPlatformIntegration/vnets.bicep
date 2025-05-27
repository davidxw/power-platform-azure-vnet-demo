param locationObjects array
param baseName string

param privateEndpointSubnetName string
param privateEndpointSubnetAddressRange string
param containerAppSubnetName string
param containerAppSubnetAddressRange string

var storageSubnet = {
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: privateEndpointSubnetAddressRange
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var containerAppSubnet = {
  name: containerAppSubnetName
  properties: {
    addressPrefix: containerAppSubnetAddressRange
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

var additionalSubnets = [
  storageSubnet
  containerAppSubnet
]

module primaryVnet 'vnet.bicep' = {
  name: 'primaryVnet'
  params: {
    locationObject: locationObjects[0]
    baseName: baseName
    ppSubnetName: 'powerplatform'
    additionalSubnets: additionalSubnets
  }
}

module secondaryVnet 'vnet.bicep' = if (length(locationObjects) == 2) {
  name: 'secondaryVnet'
  params: {
    locationObject: locationObjects[1]
    baseName: baseName
    ppSubnetName: 'powerplatform'
  }
}

module peering 'vnet_peering.bicep' = if (length(locationObjects) == 2) {
  name: 'vnetPeering'
  params: {
    primaryVnetName: primaryVnet.outputs.vnetName
    secondaryVnetName: secondaryVnet.outputs.vnetName
  }
}

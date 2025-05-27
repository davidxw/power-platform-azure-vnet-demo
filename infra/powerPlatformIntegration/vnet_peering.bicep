param primaryVnetName string
param secondaryVnetName string 

resource primaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: primaryVnetName
}

resource secondaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: secondaryVnetName
}

resource primaryToSecondaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${primaryVnetName}-To-${secondaryVnetName}'
  parent: primaryVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    remoteVirtualNetwork: {
      id: secondaryVnet.id
    }
  }
}

resource secondaryToPrimaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${secondaryVnetName}-To-${primaryVnetName}'
  parent: secondaryVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    remoteVirtualNetwork: {
      id: primaryVnet.id
    }
  }
}

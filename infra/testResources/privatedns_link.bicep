param vNetName string
param privateDnsZoneName string

var shortName = toLower(uniqueString(subscription().id, vNetName, privateDnsZoneName))
var linkName = '${privateDnsZone.name}-${shortName}-link'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vNetName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing =  {
  name: privateDnsZoneName
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: linkName
  location: 'global'
  parent: privateDnsZone
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

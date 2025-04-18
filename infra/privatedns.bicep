param privateDnsZoneName string

param primaryVnetName string = 'pp-vnet'
param secondaryVnetName string = 'pp-vnet-secondary'

@description('A list of URLs to be used for the A records.')
param aRecordIps string[]

resource primaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: primaryVnetName
}

resource secondaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: secondaryVnetName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLinkPrimary 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${privateDnsZone.name}-${primaryVnet.name}-link'
  location: 'global'
  parent: privateDnsZone
  properties: {
    virtualNetwork: {
      id: primaryVnet.id
    }
    registrationEnabled: false
  }
}

resource privateDnsZoneLinkSeconadry 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${privateDnsZone.name}-${secondaryVnet.name}-link'
  location: 'global'
  parent: privateDnsZone
  properties: {
    virtualNetwork: {
      id: secondaryVnet.id
    }
    registrationEnabled: false
  }
}

resource aRecordDefaultDomain 'Microsoft.Network/privateDnsZones/A@2020-06-01' =  if (length(aRecordIps) > 0) {
  name: '*'
  parent: privateDnsZone
  properties: {
    ttl: 3600
    aRecords: [ for ip in aRecordIps: {
        ipv4Address: ip
      }
    ]
  }
}

output privateDnsZoneId string = privateDnsZone.id

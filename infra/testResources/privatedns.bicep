param privateDnsZoneName string

param primaryVnetName string = 'pp-vnet'
param secondaryVnetName string = 'pp-vnet-secondary'

@description('A list of URLs to be used for the A records.')
param aRecordIps string[]

var shortDnsZoneName = toLower(uniqueString(subscription().id, privateDnsZoneName))


resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

module privateDnsZoneLinkPrimary 'privatedns_link.bicep' = {
  name: 'privateDnsZoneLinkPrimary-${shortDnsZoneName}'
  params: {
    vNetName: primaryVnetName
    privateDnsZoneName: privateDnsZone.name
  }
}

module privateDnsZoneLinkSecondary 'privatedns_link.bicep' = if (secondaryVnetName != '') {
  name: 'privateDnsZoneLinkSecondary-${shortDnsZoneName}'
  params: {
    vNetName: secondaryVnetName
    privateDnsZoneName: privateDnsZone.name
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

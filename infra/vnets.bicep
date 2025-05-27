
param locationObjects array
param baseName string

module vnets 'vnet.bicep' = [for locationObject in locationObjects: {
  name: '${baseName}-${locationObject.location}-vnet'
  params: {
    baseName: baseName
    subnetName: 'powerplatform'
    locationObject: locationObject
  }
}]

module peering 'vnet_peering.bicep' = if (length(locationObjects) == 2) {
  name: 'vnetPeering'
  params: {
    primaryVnetName: '${baseName}-${locationObjects[0].location}-vnet'
    secondaryVnetName: '${baseName}-${locationObjects[1].location}-vnet'
  }
  dependsOn: [
    vnets
  ]
}

// Createe a storage account with a private endpoint in the primary VNet.
// Also creates private DNS zone for blob storage, connected to both VNets.

@description('The base name to be used for all resources.')
param baseName string = 'pp-test'

@description('The location for the resources.')
param location string = 'eastus'

param primaryVnetName string = 'pp-vnet'
param secondaryVnetName string = 'pp-vnet-secondary'

@description('The name of the private DNS zone for blob storage.')
var privateDnsZoneName = 'privatelink.blob.core.windows.net'

@description('The address range for the private endpoint subnet.')
var privateEndpointSubnetAddressRange = '10.0.1.0/24'

var privateEndpointSubnetName = 'private-endpoints'

var sanitizedBaseName = replace(baseName, '-', '')

resource primaryVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: primaryVnetName
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: primaryVnet
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: privateEndpointSubnetAddressRange
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: '${sanitizedBaseName}storagexyz'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: blobService
  name: 'files'
  properties: {
    publicAccess: 'None'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${baseName}-blob-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId(primaryVnet.id, 'subnets', privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'blobConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

module privateDnsZoneModule 'privatedns.bicep' = {
  name: 'privateDnsZoneModule'
  params: {
    privateDnsZoneName: privateDnsZoneName
    primaryVnetName: primaryVnetName
    secondaryVnetName: secondaryVnetName
    aRecordIps: []
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'blob-dns-zone-group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blobDnsZoneConfig'
        properties: {
          privateDnsZoneId: privateDnsZoneModule.outputs.privateDnsZoneId
        }
      }
    ]
  }
}




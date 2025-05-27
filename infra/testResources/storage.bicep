// Createe a storage account with a private endpoint in the primary VNet.
// Also creates private DNS zone for blob storage, connected to both VNets.

@description('The base name to be used for all resources.')
param baseName string = 'pp-test'

@description('The location for the resources.')
param location string = 'eastus'

param primaryVnetName string = 'pp-vnet'
param secondaryVnetName string = 'pp-vnet-secondary'

param privateEndpointSubnetName string = 'private-endpoints'

@description('The name of the private DNS zone for blob storage.')
var privateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'

var sanitizedBaseName = replace(baseName, '-', '')

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: '${sanitizedBaseName}storagexyz'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
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
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', primaryVnetName, privateEndpointSubnetName)
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
  name: 'privateDnsZoneModule-storage'
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

output blobServiceEndpoint string = storageAccount.properties.primaryEndpoints.blob



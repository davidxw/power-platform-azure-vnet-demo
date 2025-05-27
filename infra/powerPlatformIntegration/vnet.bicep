param locationObject object
param baseName string
param ppSubnetName string = 'powerplatform'
param additionalSubnets array = []

var subnets = union(
  [
    {
      name: ppSubnetName
      properties: {
        addressPrefix: locationObject.subnetAddressRange
        delegations: [
          {
            name: 'ppDelegation'
            properties: {
              serviceName: 'Microsoft.PowerPlatform/enterprisePolicies'
            }
          }
        ]
        natGateway: {
          id: natGateway.id
        }
      }
    }
  ],
  additionalSubnets
)

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${baseName}-${locationObject.location}-pip'
  location: locationObject.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: '${baseName}-${locationObject.location}-nat'
  location: locationObject.location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicIP.id
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${baseName}-${locationObject.location}-vnet'
  location: locationObject.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        locationObject.addressSpace
      ]
    }
    subnets: subnets
  }
}

output vnetName string = vnet.name

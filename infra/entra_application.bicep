extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.2.0-preview'

param service_name string
param service_fqdn string

var app_name = '${service_name}-app'

resource application 'Microsoft.Graph/applications@v1.0' = {
  displayName: app_name
  uniqueName: app_name
  identifierUris: [
    'api://${service_fqdn}'
  ]
  web:{
    redirectUris: [
      'https://${service_fqdn}/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: true
    }
  }
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: guid(service_name)
        adminConsentDescription: 'Allow the application to access ${service_name} on behalf of the signed-in user.'
        adminConsentDisplayName: 'Access ${service_name}'
        type: 'User'
        userConsentDescription: 'Allow the application to ${service_name} on your behalf.'
        userConsentDisplayName: 'Access ${service_name}'
        value: 'user_impersonation'
      }
    ]
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
          type: 'Scope'
        }
      ]
    }
  ]
  passwordCredentials: [
    {
      displayName: 'auth-secret'
    }
  ]
}

resource sp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: application.appId
}

output appId string = application.appId

@secure()
output app_client_secret string = application.passwordCredentials[0].secretText

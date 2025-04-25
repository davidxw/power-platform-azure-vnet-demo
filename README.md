# Power Platform Azure VNet Demo

Scripts from:

https://github.com/microsoft/PowerApps-Samples/tree/master/powershell/enterprisePolicies


Add paramaters to custom connectors:

https://philcole.org/post/environment-specific-custom-connector-endpoints/

Using Entra ID (preauth):

https://www.blimped.nl/calling-entra-id-secured-azure-function-from-power-automate/

@pnp/cli-microsoft365
Add authorized client app to Azure AD (Expose an API, Authorized client applications)


### Steps to run the demo:

1. Create Azure resources (bicep)
1. Set up local powershell environment (install modules)
1. Connect Power Apps environment to Azure VNet (powershell)

#### If using Entra ID (preauth):

1. Update Entra ID app registration (powershell)
1. Add Authorized client app to Azure AD (powershell - NO SCRIPT YET)([Update AAD app API settings](https://learn.microsoft.com/en-us/powershell/module/az.resources/update-azadapplication?view=azps-13.4.0#-api))

#### If calling an inerally hosted API:

1. Create custom connector

#### Create flow

1. Create Power Automate flow (using custom connector)


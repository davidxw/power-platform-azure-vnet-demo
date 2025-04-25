# Power Platform Azure VNet Samples and Demo

This repo contains templates, scripts and guides to help you set up and test a Power Platform environment with Azure VNet integration. Most of the contenet in the repo is based on the Microsoft documentation and samples, but it's not always easy to find and I have added some additional information and examples to help you get started.

The can find the  Microsoft documentation for Azure VNet integration with Power Platform [here](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview).

Before you start, please note that this is a demo and not a production ready solution. The templates and scripts are provided as-is and should be used at your own risk. I've also assumed that you have good knowledge of Azure, Power Platform and PowerShell - there are quite a few steps to get everything set up and running and I haven't provided detailed instructions for each step.

The demo contains the following sections - you can choose to use all or some of them:

* Bicep template and a guide to create Azure resources (inlcuding VNets) and link them to a Power Platform environment - if you complete this step you will be able to use private Azure resources in your Power Platform environment and call them from Power Apps and Power Automate flows.
* Samples for the Power Platform connectors that support connectivity to resources in an Azure VNet. You can use these samples after you have set up the Azure resource contained in this demo, or you can modify them to use your own Azure resources. Demos of the following connectors are included:
  * Azure Blob Storage 
  * Custom Connectors - connecting to your custom APIs
  * HTTP with Microsoft Entra ID (preauthorized) - connecting to your custom APIs with Entra ID authentication 

### Prerequisites: 

Azure CLI

## Creating Azure Resources and Conecting to Power Platform

To set up a demo environment with Power Platform Azure VNet integration, you will need to complete the following steps:
1. Create the required Azure resources using the Bicep template provided in this repo
1. Set up your local PowerShell environment with the required modules
1. Connect your Power Platform environment to the Azure VNet using PowerShell

These steps are described in the [Microsoft documentation](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-setup-configure), but I have simplified the process by providing a Bicep templates to create the required Azure resources.

### 1. Create the required Azure resources using the Bicep template provided in this repo

Clone this repo to your local machine and open repo in Visual Studio Code. From a teminal window, run the following command from the `infra` directory to create the Azure resources:

``` powershell
$rg = "<your resource group name>"
$name = "<base name for your resources>"
az deployment group create --resource-group $rg --template-file ./main.bicep --parameters --name $name
``` 

This script will create the following resources in your Azure subscription:
* Two Azure VNets, one in each of the regions association with the Power Platform environment. The default regions are `eastus` and `westus` for Power Plaform envrionments in the United States.  If your Power Plaform environment is in a different region see the [supported region list](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview#supported-regions) and update the `pimaryLocation` and `secondaryLocation` parameters in the Bicep template appropriately. Note that the template currently doesn't support Power Platform regions with a single associated Azure region. The created VNets are peered.
* A subnet in each VNet delegated to Power Platform. The subnets are named `pp` and are delegated to `Microsoft.PowerPlatform/enterprisePolicies`
* A `NetworkInjection` Enterprise Policy - this policy is required to connect the Power Platform environment to the Azure VNets. Note that actual connection is performed in a later step.
* An Azure Storage account in the primary region, with a private endpoint in the primary VNet. The storage account is configured with a private DNS zone and a private link service connection to the VNet, and public access is disabled. The storage account is configured with a single blob container named `files`.
* Two Azure Container Apps in a Container Apps environment in the primary region. The Container Apps Environment is deployed into the primary Vnet with external ingress allowed from the VNet only. Each container app hosts a simple API that responds to a `/api/ping` request, and one of the container apps is protected with Entra ID authentication. 

The Storage account and Container Apps are deployed using separate Bicep modules - if you don't need these resources you can comment them out in the main Bicep template.

The Bicep template writes a number of values to the outputs collection - these values are required if you are also going to set up a custom conenctor to call the APIs, or if you are going to call the protected API using Entra ID authentication. The values are:

`policyArmId` - the resource ID of the `NetworkInjection` Enterprise Policy. This is required to connect the Power Platform environment to the Azure VNet.
`containerAppNoauthFQDN` - the FQDN of the unprotected Container App. This is required to set up a custom connector to call the API.
`containerAppauthFQDN` - the FQDN of the protected Container App. This is required to set up the HTTP with Microsoft Entra ID (preauthorized) connector to call the API.
`containerAppAuthAppId` - the application ID of the Entra ID app registration used to protect the Container App. This is required to set up the HTTP with Microsoft Entra ID (preauthorized) connector to call the API.

### 2. Set up your local PowerShell environment with the required modules





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
1. Add Authorized client app to Azure AD (powershell)([Update AAD app API settings](https://learn.microsoft.com/en-us/powershell/module/az.resources/update-azadapplication?view=azps-13.4.0#-api))

#### If calling an inerally hosted API:

1. Create custom connector

#### Create flow

1. Create Power Automate flow (using custom connector)


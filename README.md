# Power Platform Azure VNet Samples and Demo

This repo contains templates, scripts and guides to help you set up and test a Power Platform environment with Azure VNet integration. Most of the content in the repo is based on the Microsoft documentation and samples - this documentation is not always easy to find and I have added some additional information and examples to help you get started.

You can find the  Microsoft documentation for Azure VNet integration with Power Platform [here](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview).

> [!NOTE]
> Before you start, please note that this is a demo and not a production ready solution. The templates and scripts are provided as-is and should be used at your own risk. I've also assumed that you have good knowledge of Azure, Power Platform and PowerShell - there are quite a few steps to get everything set up and running and I haven't provided detailed instructions for each step.

The demo contains the following sections - you can choose to use all or some of them:

* Bicep template and a guide to create Azure resources (inlcuding VNets) and link them to a Power Platform environment - if you complete this step you will be able to use private Azure resources in your Power Platform environment and call them from Power Apps and Power Automate flows using supported connectors.
* Samples for the Power Platform connectors that support connectivity to resources in an Azure VNet. You can use these samples after you have set up the Azure resource contained in this demo, or you can modify them to use your own Azure resources. Demos of the following connectors are included:
  * Azure Blob Storage 
  * Custom Connectors - connecting to your custom APIs
  * HTTP with Microsoft Entra ID (preauthorized) - connecting to your custom APIs with Entra ID authentication 

### Prerequisites: 

Azure CLI
Power Platform Admin Access
Entra ID Application Manager Access (if using Entra ID authentication)

## Creating Azure Resources and Conecting to Power Platform

To set up a demo environment with Power Platform Azure VNet integration, you will need to complete the following steps:
1. Set up your local PowerShell environment with the required modules, and you Azure subscription with the required features and providers. This can be done manually or using PowerShell scripts provided in this repo.
1. Create the required Azure resources using the Bicep template provided in this repo
1. Connect your Power Platform environment to the Azure VNet using PowerShell

These steps are described in the [Microsoft documentation](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-setup-configure), but I have simplified the process by providing a Bicep templates to create the required Azure resources.

### 1. Set up your local PowerShell environment with the required modules

Management of the connection from Power Platform to an Azure VNet is done using PowerShell. Before you can run the PowerShell scripts, you need to set up your local PowerShell environment and you Azure subscription with the required modules and services. Two scripts are [provided by Microsoft](https://github.com/microsoft/PowerApps-Samples/blob/master/powershell/enterprisePolicies/README.md#how-to-run-setup-scripts) to help you with this process, and these have been included in the `scripts` folder of this repo. The scripts are:

* `SetupSubscriptionForPowerPlatform.ps1` - registers the Azure subscription for Microsoft.PowerPlatform resource provider and also allow lists the subscription for enterprisePoliciesPreview feature. Alternatively you can register the required providers and features with the following Azure CLI commands:
  ```
  az provider register --namespace Microsoft.PowerPlatform
  az feature register --name enterprisePoliciesPreview --namespac  e Microsoft.PowerPlatform
  ```
* ` InstallPowerAppsCmdlets.ps1` - installs the required modules to run Enterprise Policies scripts. Alternatively you can manually install the following PowerShell modules:

  * Az
  * Microsoft.PowerApps.Administration.PowerShell
  * Microsoft.PowerApps.PowerShell


### 2. Create the required Azure resources using the Bicep template provided in this repo

Clone this repo to your local machine and open repo in Visual Studio Code. From a teminal window, run the following commands from the `infra` directory to create the Azure resources:

``` powershell
$rg = "<your resource group name>"
$name = "<base name for your resources>"
az group create --name $rg --location <your location>
az deployment group create --resource-group $rg --template-file ./main.bicep --parameters baseName=$name
``` 

This script will create the following resources in your Azure subscription:

![Azure diagram](docs/images/azure.drawio.svg)
#### Core Resources (Required for Power Platform Azure VNet integration):
* Two Azure VNets, one in each of the regions associated with your Power Platform environment. The default regions are `eastus` and `westus` for Power Plaform envrionments in the United States.  If your Power Plaform environment is in a different region see the [supported region list](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview#supported-regions) and update the `pimaryLocation` and `secondaryLocation` parameters in the Bicep template appropriately. The created VNets are peered. If your Power Platform environment is in a region with a single Azure region (e.g. Sweden or Singapore) you only need a single VNet. Update the `secondaryLocation` parameter to `''` (either in the template or passed as a paramater) and the template will only create the primary VNet.
* A subnet in each VNet delegated to Power Platform. The subnets are named `powerplatform` and are delegated to `Microsoft.PowerPlatform/enterprisePolicies`
* A `NetworkInjection` Enterprise Policy - this policy is required to connect the Power Platform environment to the Azure VNets. Note that actual connection is performed in a later step.
#### Test Resources (required for the "Samples for Testing the Virtual Network Connection" section below):
If you only want to set up the Azure resources required for Power Platform Azure VNet integration, you can set the `createTestResources` parameter to `false` when running the Bicep template - the resources below will not be created. The default value for this parameter is `true` so without modification the Bicep template will create the following resources:
* An Azure Storage account in the primary region, with a private endpoint in the primary VNet. The storage account is configured with a private DNS zone, and public access is disabled. A single blob container named `files` is added to the storage account.
* Two Azure Container Apps in a Container Apps environment in the primary region. The Container Apps Environment is deployed into the primary Vnet with external ingress allowed from the VNet only. Each container app hosts a simple API that responds to a `/api/ping` request, and one of the container apps is protected with Entra ID authentication. 

The Bicep template writes a number of values to the outputs collection - these values are required if you are also going to set up a custom conenctor to call the APIs, or if you are going to call the protected API using Entra ID authentication. The values are:

* `policyArmId` - the resource ID of the `NetworkInjection` Enterprise Policy. This is required to connect the Power Platform environment to the Azure VNet.
* `containerAppNoauthFQDN` - the FQDN of the unprotected Container App. This is required to set up a custom connector to call the API.
* `containerAppauthFQDN` - the FQDN of the protected Container App. This is required to set up the HTTP with Microsoft Entra ID (preauthorized) connector to call the API.
* `containerAppAuthAppId` - the the Entra ID app registration ID for the protected Container App. This is required to set up the HTTP with Microsoft Entra ID (preauthorized) connector to call the API.
* `blobServiceEndpoint` - the blob service endpoint of the storage account. This is required to set up a Blob Storage connector

### 3. Connect your Power Platform environment to the Azure VNet using PowerShell

To connect your Power Plaform environment you will need to run the `NewSubnetInjection.ps1` script (the original is [here](https://github.com/microsoft/PowerApps-Samples/tree/master/powershell/enterprisePolicies#7-set-subnet-injection-for-an-environment), can also be found in the `scripts` folder in this repo). This script takes the following parameters:

* `-environmentId` - the ID of the Power Platform environment to connect to the Azure VNet. This can be found in the Power Platform admin center. Note this is not the name of the environment, but the GUID that is used to identify the environment in Azure (e.g. `Default-cf7a4a08-6d30-40c8-bd52-d6f7494c0541`)
* `-policyArmId` - the resource ID of the `NetworkInjection` Enterprise Policy created be the Bicep templates in the previous step. This can be found by looking for the value of the `policyArmId` output from the Bicep template, or by looking in the Azure portal for the `NetworkInjection` policy in your resource group. The resource ID will look something like this: `/subscriptions/<subscriptionId>/resourceGroups/<rgName>/providers/Microsoft.PowerPlatform/enterprisePolicies/<policyName>`

``` powershell
 .\NewSubnetInjection.ps1  -environmentId "Default-cf7a4a08-6d30-40c8-bd52-d6f7494c0541" -policyArmId "/subscriptions/68dfa90d-6200-4bc6-bdad-178344084a61/resourceGroups/pp-vnet/providers/Microsoft.PowerPlatform/enterprisePolicies/pp-vnet-policy"
```

To check if the environment was successfully connected to the Azure VNet you need to check the Power Platform admin center. Navigate to `Manage > Environments > <your environment>`, and check the recent operations list - you should see an operation of type `New Network Injection Policy` with a status of `Succeeded`. 

> [!NOTE]
> Azure VNet integration is only supported for Power Platform Managed Environments. 

To remove the connection to the Azure VNet you can use the `RevertSubnetInjection.ps1` script. This script takes the same parameters as the `NewSubnetInjection.ps1` script, and will remove the connection to the Azure VNet.

## Samples for Testing the Virtual Network Connection

With Azure resources created and the Power Platform environment connected to the Azure VNet, you can now test the connection to the Azure VNet using some supported connectors. 

### Azure Blob Storage

The simplest way to test the connection to the Azure VNet is to use the Azure Blob Storage connector. This connector supports connectivity to resources in an Azure VNet, and can be used to read, write and list files to the Azure Storage account created by the Bicep template. Because public connectivity to this storage account account is disabled, any succssful operation using the Azure Blob Storage connector will confirm that the connection to the Azure VNet is working.

* Create a new Power Automate flow in your Power Platform environment 
* Add the `List blobs (V2)` action, and use the key from the Storage account to create a connection.
* In the "Storage account or blob endpoint" field you will need to enter the FQDN of the storage account. This value is output by the Bicep template, and is the name of the storage account followed by `.blob.core.windows.net` (e.g. `https://mystorageaccount.blob.core.windows.net`). 
* Select "files" as the folder. It doesn't matter if there are no files in the folder, we are just testing the connection

The properties of the action should look something like this:

![List files properties](docs/images/blob.png)

Run the flow and check the output of the `List blobs (V2)` action. If the connection to the Azure VNet is working, you should see a list of blobs in the output.

Note that you haven't had to do anything special to use this connector to connect to resources in the Azure VNet - Azure DNS takes care of mapping the storage account name to the private endpoint in the VNet, and the Azure Blob Storage connector uses the same connection string as it would for a public storage account. This also applies to some of the other connectors that support connectivity to resources in an Azure VNet:

* SQL Server
* Azure SQL Data Warehouse
* Azure Queues
* Azure Key Vault
* Azure File Storage

### Connecting to your custom APIs

While the above connectors support connectivity to Azure resources in an Azure VNet, you may also want to connect to your own custom APIs. Unfortunately the "HTTP" connector does not support connectivity to resources in an Azure VNet - if you have a custom API that you want to connect to you have a couple of options:

* Create a custom connector
* Use the HTTP with Microsoft Entra ID (preauthorized) connector (if you are using Entra ID authentication)

The Bicep templates in this repo deploys two Azure Container Apps which can be used to test these options. One container app has no authentication (used to test a custom connector), and the other is protected with Entra ID authentication (used to test the HTTP with Microsoft Entra ID connector). Each app contains a simple API that responds to a `/api/ping` request.

#### Custom Connectors

You can use two approaches to create a custom connector to connect to the unprotected Container App API:

1. Mnually create a custom connector in Power Platform
2. Create a custom connector using the the `paconn` CLI tool and API properties and definition files in this repo.

The advantage of using the second approach is that the connector definition files in this repo contain the required settings to make the value of your API host a property of the connection - if you manually create the custom connector the API host will be hardcoded in the connector.

##### Manually create a custom connector in Power Platform

1. In Power Platform, navigate to `More > Discover All > Data > Custom Connectors` (you can pin this to the left hand menu for easier access)
1. Select `New custom connector > Import an OpenAPI file`
1. Enter a name for your connector, and select the `apiDefinition.swagger.json` file from the `connectors\api-health-check` folder in this repo. This file contains the OpenAPI definition for the API hosted in the Container App. 
1. Update the host name to match your environment. The host name is the FQDN of the unprotected Container App, and is output by the Bicep template. The FQDN will look something like this: `<name>.<region>.azurecontainerapps.io` (e.g. `pptest-ca-noauth.eastus.azurecontainerapps.io`).
1. Select `Create Connector` (you can leave all the other settings unchanged)
1. After the connector is created you can test the connection by selecting `6.Test` and then `Test Operation`. You should see a successful response from the API.

You can then use the custom connector in a Power Automate flow. To do this, create a new flow and add the `Ping` action from the custom connector. The connection and action have no custom properties. If you run the flow you should see a successful response from the API.

##### Import a custom connector using the `paconn` CLI tool

The full details for using the `paconn` CLI tool are in the [Microsoft documentation](https://learn.microsoft.com/en-us/connectors/custom-connectors/paconn-cli), but here are the high level steps:

1. Install the `paconn` CLI tool as per the documentation link above
1. From a terminal window, run the following commands from the root of the repo:
```powershell
paconn login
paconn create -d .\connectors\api-health-checks\apiDefinition.swagger.json -p .\connectors\api-health-checks\apiProperties.json
```
This will create a custom connector in your Power Platform environment called `API Health Checks`. The connector is configured with a custom property for the API host - if you add this connector to a flow you will be prompted for this value. The host name is the FQDN of the unprotected Container App, and is output by the Bicep template. The FQDN will look something like this: `<name>.<region>.azurecontainerapps.io` (e.g. `pptest-ca-noauth.eastus.azurecontainerapps.io`).

![ping connection](docs/images/ping.png)

(Thanks to [this](https://philcole.org/post/environment-specific-custom-connector-endpoints/) blog post for instructions on how to set up the custom property for the API host)

#### Use the HTTP with Microsoft Entra ID (preauthorized)  

The final sample in this repo is a demo of the HTTP with Microsoft Entra ID (preauthorized) connector. This connector allows you to call your custom APIs that are protected with Entra ID authentication, and, like most use cases with Entra ID, there are quite a few moving parts. For this particular demo we'll be attempting to call an API that has been deployed into an Azure Container App, which has been protected with Entra ID authentication. The protected container app deplopyed by the Bicep template in this repo is called `<your app name>-ca-auth`.

Follow the steps below to set up the HTTP with Microsoft Entra ID (preauthorized) connector:

1. Add an `Invoke an HTTP request` action from the `HTTP with Microsoft Entra ID (preauthorized)` connector to your flow, and when prompted for the connection details enter the following values:
   * **Connection Name**: A name for the connection (e.g. `HTTP with Entra ID`)
   * **Authentication Type**: `Login with Microsoft Entra ID`
   * **Microsoft Entra ID Resource URI**: The Application ID URI of the Entra authentication app registration created by the Bicep template for the authorized container. To get the application ID you can look for the `containerAppAuthAppId` output value from the bicep template, or navigate to the Security -> Authentication tab of the `pp-vnet-ca-auth` container app in the Azure portal, and copy the value of the `App (client) ID` field. Enter this value as `api://<id>` (e.g. `api://d22caf39-23f6-4e9d-8a86-990fd406bdfe`).
   * **Base Resource URL**: The FQDN of the `<your app anme>-ca-noauth` container app deployed by the Bicep template. This is the value of the `containerAppauthFQDN` output from the Bicep template. The FQDN will look something like this: `<your app anme>-ca-auth.<generated_name>.<region>.azurecontainerapps.io` 

     The properties of the action should look something like this:

     ![HTTP with Entra ID](docs/images/entra_connection.png)

1. Sign in to the connection using your Entra ID credentials, and you will receive an error similar to the following:

   ![Entra ID error](docs/images/entra_error.png)

   The reasons you get this error are explained [this](https://www.blimped.nl/calling-entra-id-secured-azure-function-from-power-automate/) blog post and are due to the fact that the Entra ID authentication app registration is not configured to allow access from the Power Platform environment (note that this blog post is referring to the use of this connector for APIs that are not behind a VNet, but the same principles apply). To fix this you need to add the Power Platform environment as an authorized client app in the Entra ID app registration. There are a number of ways to this (as there are many ways to interact with Entra ID) - the blob post uses the M365 CLI, and there is a script in the [Microsoft Documentation](link) that uses PowerShell and the Entra ID cmdlets. This script has some hardcoded values though, so in this repo I have provided a more generic version that you can use to complete the setup for this demo.

   To run the script in this repo, follow the steps below:    

   1. Note the Application ID for the `App Service` application shown in the error message above (highlighted in the image). This will be used as the `ConnectorHostAppAppId` parameter in the script below. This is the Entra ID app registration for the connector host, and is used to allow the connector host to call your API with the required scopes.
   1. Also note the Application ID for the Entra ID app registration created by the Bicep template for the authorized container (used in step 1 above). This is the `ApiHostAppId` parameter in the script below.
   1. From the scripts folder in this repo, run the `ManagePermissionGrant.ps1` script as follows:

   ```powershell
   .\ManagePermissionGrant.ps1 -ConnectorHostApp 7ab7862c-4c57-491e-8a45-d52a7e023983 -ApiHostAppId 9635f9b6-0b73-4da2-841f-4d5ef45e3334
   ```

   4. Follow the prompts to add the Power Platform environment as an authorized client app in the Entra ID app registration for the authorized container. The script will also add the required API permissions for the connector host to allow it to call your API with the required scopes.
1. Go back to the Power Automate flow and try to create the connection again. This time you should be able to sign in successfully and the connection should be created.
1. Finally, add the HTTP pamarameters to the action. The parameters are as follows:
    * **Method**: `GET`
    * **URI**: The FQDN for the authenticated container app, followed by `\api\environment`, e.g. `https://pp-vnet-ca-auth..<generated_name>.<region>.azurecontainerapps.io.azurecontainerapps.io/api/environment` 
1. Run the flow and check the output of the action. You should see a successful response from the API

> [!NOTE]
> If you receive a 403 error in the `Invoke an HTTP request` action when running the flow, open the authenticated container app in the portal and navigate the the "Settings" -> "Authentication" page.  Edit the Microsoft identity provider and check if the "Additional checks" -> "Allowed client applications" list contains the Application ID of the connector host app (the value of the `ConnectorHostAppAppId` parameter in the script above). If not add the Application ID to the list and save the changes. This is required to allow the connector host to call your API with the required scopes.
>
> You can alternatively set this to "Allow requests from any client application" but we have found that this setting is not saved correctly

## Wrap Up

If you have run all the steps in this demo you should have a working Power Platform environment with Azure VNet integration, and you should have a working Power Platform flow that looks something like this:
  
![Power Automate flow](docs/images/flow.png)

You can drill into the results of each action but the fact that each has succeeded is a good indication that the connection to the Azure VNet is working.

## Links

* [Microsoft Power Platform VNet Integration Documentation](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview)
* [Source Setup Scripts](https://github.com/microsoft/PowerApps-Samples/blob/master/powershell/enterprisePolicies/README.md#how-to-run-seup-scripts)
* [Supported Region List](https://learn.microsoft.com/en-in/power-platform/admin/vnet-support-overview#supported-regions)
* [paconn Tool](https://learn.microsoft.com/en-us/connectors/custom-connectors/paconn-cli)
* [Environment Specific Custom Connector Endpoints](https://philcole.org/post/environment-specific-custom-connector-endpoints/) 
* [Calling Entra ID secured Azure Functions from Power Automate](https://www.blimped.nl/calling-entra-id-secured-azure-function-from-power-automate/) 

param(
	[Parameter(Mandatory = $false)]
	[string]$ConnectorHostAppAppId = $null,
	[Parameter(Mandatory = $false)]
	[string]$ApiHostAppId = $null,
	[Parameter(Mandatory = $false)]
	[switch]$Force = $false
)

Write-Host "########################################################"
Write-Host "# 'HTTP with Microsoft Entra ID' connectors - Permission grant configuration"
Write-Host "# This script will guide you through the process of granting the required permissions"
Write-Host "# to a Connectors host application (e.g. PowerApps, App Service)"
Write-Host "########################################################"

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module Microsoft.Graph -Scope CurrentUser -WarningAction Ignore
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Identity.SignIns
$ErrorActionPreference = "Stop"

Disconnect-Graph -ErrorAction Ignore

if (!$ConnectorHostAppAppId) {
	$ConnectorHostAppAppId = Read-Host "Enter the appId of the Connector host application (e.g. PowerApps, App Service, etc.)"
}

if (!$ApiHostAppId) {
	$ApiHostAppId = Read-Host "Enter the appId of the Azure service hosting your API (e.g. Azure App Service, Azure Function, etc.)"
}

# Connect to MS Graph - update if you are using a different environment
$selectedEnvName = "Global"

Connect-MgGraph -Environment $selectedEnvName -Scopes "User.ReadWrite.All Directory.AccessAsUser.All" -NoWelcome

# Find Service principal in the local tenant associated to the reuired Microsoft 1st party app

$ConnectorHostAppServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$ConnectorHostAppAppId'"

If (!$ConnectorHostAppServicePrincipal) {
	Write-Host "No service principal was found in the current tenant with appId: $ConnectorHostAppAppId. Attempting to create one."
	$AppIDForSpCreation = @{
		"AppId" = "$ConnectorHostAppAppId"
	}

	$ConnectorHostAppServicePrincipal = New-MgServicePrincipal -BodyParameter $AppIDForSpCreation

	If (!$ConnectorHostAppServicePrincipal) {
		Write-Warning "Not able to create a service principal for appId : $ConnectorHostAppAppId."
		Exit
	}
}

$ConnectorHostAppServicePrincipalId = $ConnectorHostAppServicePrincipal.Id
$ConnectorHostAppServicePrincipalDisplayName = $ConnectorHostAppServicePrincipal.DisplayName

Write-Host "ConnectorHostApp Service principal found:"
$ConnectorHostAppServicePrincipal | Format-Table -wrap -auto


# Select scopes for the 1st party app selected
# Find SP associated to the selected app
$apiHostSP = Get-MgServicePrincipal -Filter "appId eq '$ApiHostAppId'"

If (!$apiHostSP) {
	Write-Warning "No service principal found in the current tenant with appId: $ApiHostAppId"
	Exit
}

$apiHostSPId = $apiHostSP.Id

# get scopes for the selected app
$scopes = $apiHostSP.Oauth2PermissionScopes
$joinedScopes = $scopes | Join-String -Property {$_.Value} -Separator ' '


# if you want to update the consent type to a spcific user, change this variable to "Principal"
$consentType = "AllPrincipals"

# Select a consent type (AllPrincipals vs Principal)
if ($consentType -eq "AllPrincipals") {
	$grantParams = @{
		clientId    = $ConnectorHostAppServicePrincipalId
		consentType = $consentType
		resourceId  = $apiHostSPId
		scope       = $joinedScopes
	}
}
else {
	# let the user select a specific principal
	$users = Get-MgUser -All | Select-Object ID, DisplayName, Mail, UserPrincipalName
	$selectedUser = $users | Out-GridView -Title "Choose a user" -OutputMode Single

	$grantParams = @{
		clientId    = $ConnectorHostAppServicePrincipalId
		consentType = $consentType
		principalId = $selectedUser.Id
		resourceId  = $apiHostSPId
		scope       = $joinedScopes
	}
}

# Display current grants for the service principal and resource
$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$ConnectorHostAppServicePrincipalId' and resourceId eq '$apiHostSPId'"

Write-Host "The following grant is going to be persisted:"
$grantParams | Format-Table -wrap -auto

# Create/Update a delegated permission grant represented by an oAuth2PermissionGrant object (delete existing one if any)
if ($grantParams.consentType -eq "AllPrincipals") {
	$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$ConnectorHostAppServicePrincipalId' and resourceId eq '$apiHostSPId' and consentType eq 'AllPrincipals'"
	
	if ($existingOauth2PermissionGrant) {
		Write-Warning "An existing oAuth2PermissionGrant object was found with the same key properties. (clientId: $ConnectorHostAppServicePrincipalId, resourceId: $apiHostSPId, consentType: AllPrincipals)"
	}
}
elseif ($grantParams.consentType -eq "Principal") {
	$grantParamsPrincipalId = $grantParams.principalId
	$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$ConnectorHostAppServicePrincipalId' and resourceId eq '$apiHostSPId' and consentType eq 'Principal'" | Where-Object { $_.PrincipalId -eq $grantParamsPrincipalId }
	
	if ($existingOauth2PermissionGrant) {
		Write-Warning "An existing oAuth2PermissionGrant object was found with the same key properties. (clientId: $ConnectorHostAppServicePrincipalId, resourceId: $apiHostSPId, consentType: Principal, principalId: $grantParamsPrincipalId)"
	}
}

if ($existingOauth2PermissionGrant) {
	Write-Warning "This means that the existing oAuth2PermissionGrant object is about to be updated with the new parameters provided."
	Write-Warning "Existing permission grant:"
	$existingOauth2PermissionGrant | Format-Table -wrap -auto

	if (!$Force) {
		if ($Host.UI.PromptForChoice("Confirm permission grant update", "Do you want to proceed and update the above permission grant?", ('&Yes', '&No'), 0) -eq 1) {
			Write-Warning "Execution terminated."
			Exit
		}
	}

	Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existingOauth2PermissionGrant.Id -BodyParameter $grantParams
}
else {
	#New-MgOauth2PermissionGrant -BodyParameter $grantParams # This command is not working as expected, so we are using the parameters directly instead
	New-MgOauth2PermissionGrant -ClientId $grantParams.clientId -ConsentType $grantParams.consentType -PrincipalId $grantParams.principalId -ResourceId $grantParams.resourceId -Scope $grantParams.scope
}

Write-Host "A delegated permission grant was persisted with the following parameters:"
$grantParams | Format-Table -wrap -auto

# add Authorized client application

# get application
$aad_application = Get-MgApplicationByAppId -AppId $ApiHostAppId

$aad_application.Api.preAuthorizedApplications

if (!$aad_application) {
	Write-Host "No application found with the specified appId: $ApiHostAppId"
	Exit
}

$aad_application.Api.preAuthorizedApplications = $aad_application.Api.preAuthorizedApplications | ForEach-Object {
	# Remove the pre-authorized application if it already exists
	if ($_.AppId -eq $ConnectorHostAppAppId) {
		Write-Host "Removing existing pre-authorized application with appId: $($_.ApplicationId)"
		return $null
	}
	else {
		return $_
	}
}

# Update the application with the pre-authorized application, all scopes are added by default
$aad_application.Api.preAuthorizedApplications += @{
	AppId          = $ConnectorHostAppAppId
	DelegatedPermissionIds = $scopes | ForEach-Object {$_.Id}
}

Update-MgApplicationByAppId -AppId $ApiHostAppId -Api $aad_application.Api

Write-Host "The application with appId $ApiHostAppId has been updated with the pre-authorized application."

Disconnect-MgGraph
Write-Host "Script execution completed successfully"
Write-Host "########################################################"
Write-Host "# 'HTTP with Microsoft Entra ID' connectors - Permission grant configuration"
Write-Host "# This script will guide you through the process of granting the required permissions"
Write-Host "# to the HttpWithAADApp Microsoft 1st party app 'ServiceApp_NoPreAuths' to access the selected resources."
Write-Host "########################################################"

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module Microsoft.Graph -Scope CurrentUser -WarningAction Ignore
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Identity.SignIns
$ErrorActionPreference = "Stop"

Disconnect-Graph -ErrorAction Ignore

if($Host.UI.PromptForChoice("Cloud selection", "Most customers access to the Global Azure environment. Do you want to connect using azure global or do you want to select from a list?", ('&Azure Global (recommended)', '&Select from a list (advanced)'), 0) -eq 0)
{
	$selectedEnvName = "Global"
}
else 
{
	$selectedEnv = Get-MgEnvironment | Out-GridView -Title "Choose Cloud Environment" -OutputMode Single

	If (!$selectedEnv)
	{
		Write-Warning "No environment selected. Please select an environment and try again."
		Exit
	}

	$selectedEnvName = $selectedEnv.Name
}

Connect-MgGraph -Environment $selectedEnvName -Scopes "User.ReadWrite.All Directory.AccessAsUser.All" -NoWelcome

# Find Service principal in the local tenant associated to the reuired Microsoft 1st party app

$HttpWithAADAppAppId = Read-Host "Enter the appId of the PowerApp or App Service Microsoft 1st party app"

$HttpWithAADAppServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$HttpWithAADAppAppId'"

If (!$HttpWithAADAppServicePrincipal)
{
	Write-Host "No service principal was found in the current tenant with appId: $HttpWithAADAppAppId. Attempting to create one."
 	$AppIDForSpCreation=@{
   		"AppId" = "$HttpWithAADAppAppId"
   	}

	$HttpWithAADAppServicePrincipal = New-MgServicePrincipal -BodyParameter $AppIDForSpCreation

 	If (!$HttpWithAADAppServicePrincipal)
	{
		Write-Warning "Not able to create a service principal for appId : $HttpWithAADAppAppId."
		Exit
  	}
}

$HttpWithAADAppServicePrincipalId = $HttpWithAADAppServicePrincipal.Id
$HttpWithAADAppServicePrincipalDisplayName = $HttpWithAADAppServicePrincipal.DisplayName

Write-Host "HttpWithAADApp Service principal was found:"
$HttpWithAADAppServicePrincipal | Format-Table -wrap -auto


$selectedAppId = Read-Host "Enter the appId of the Azure service hosting your API (e.g. Azure App Service, Azure Function, etc.)"

# Select scopes for the 1st party app selected
# Find SP associated to the selected app
$selectedSP = Get-MgServicePrincipal -Filter "appId eq '$selectedAppId'"

If (!$selectedSP)
{
	Write-Warning "No service principal found in the current tenant with appId: $selectedAppId"
	Exit
}

$selectedSPId = $selectedSP.Id

# List of Admin and User Scopes
$scopes = $selectedSP.Oauth2PermissionScopes | Sort-Object Value | Select-Object Type, Value, UserConsentDisplayName, UserConsentDescription
$selectedScopes = $scopes | Out-GridView -Title "Choose Scopes" -OutputMode Multiple

$joinedScopes = $selectedScopes | Join-String -Property {$_.Value} -Separator ' '
Write-Host "The following user scopes have been selected: $joinedScopes"

If (!$selectedScopes)
{
	Write-Warning "No scopes selected. Please select at least one and try again."
	Exit
}

# Select a consent type (AllPrincipals vs Principal)
if($Host.UI.PromptForChoice("Select consent type", "Do you want the service principal '$HttpWithAADAppServicePrincipalDisplayName' ($HttpWithAADAppServicePrincipalId) to be able to impersonate all users?", ('&Yes', '&No (I need to select a specific user)'), 0) -eq 0)
{
	$grantParams = @{
		clientId = $HttpWithAADAppServicePrincipalId
		consentType = "AllPrincipals"
		resourceId = $selectedSPId
		scope = $joinedScopes
	}
}
else 
{
	# let the user select a specific principal
	$users = Get-MgUser -All | Select-Object ID, DisplayName, Mail, UserPrincipalName
	$selectedUser = $users | Out-GridView -Title "Choose a user" -OutputMode Single

	$grantParams = @{
		clientId = $HttpWithAADAppServicePrincipalId
		consentType = "Principal"
		principalId = $selectedUser.Id
		resourceId = $selectedSPId
		scope = $joinedScopes
	}
}

# Display current grants for the service principal and resource
$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$HttpWithAADAppServicePrincipalId' and resourceId eq '$selectedSPId'"

if($existingOauth2PermissionGrant)
{
	Write-Host "The service principal '$HttpWithAADAppServicePrincipalDisplayName' ($HttpWithAADAppServicePrincipalId) has the following oAuth2PermissionGrant objects already defined for resourceId '$selectedSPId':"
	$existingOauth2PermissionGrant | Format-Table -wrap -auto

	# allow deletion of existing grants
	if($Host.UI.PromptForChoice("Grant deletion", "Do you want to delete any of the existing grants?", ('&No', '&Yes, I want to first delete existing grants'), 0) -eq 1)
	{
		# deletion flow
		$selectedGrantsToDelete = $existingOauth2PermissionGrant | Out-GridView -Title "Select the grants you want to delete" -OutputMode Multiple

		Write-Host "The following grants are going to be deleted:"
		$selectedGrantsToDelete | Format-Table -wrap -auto
		$selectedGrantsToDelete | ForEach-Object { Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId $_.Id }
	}
}
else
{
	Write-Host "No existing oAuth2PermissionGrant object were found for service principal '$HttpWithAADAppServicePrincipalDisplayName' ($HttpWithAADAppServicePrincipalId) and resourceId '$selectedSPId'"
}

Write-Host "The following grant is going to be persisted:"
$grantParams | Format-Table -wrap -auto

# Create/Update a delegated permission grant represented by an oAuth2PermissionGrant object (delete existing one if any)
if ($grantParams.consentType -eq "AllPrincipals")
{
	$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$HttpWithAADAppServicePrincipalId' and resourceId eq '$selectedSPId' and consentType eq 'AllPrincipals'"
	
	if($existingOauth2PermissionGrant)
	{
		Write-Warning "An existing oAuth2PermissionGrant object was found with the same key properties. (clientId: $HttpWithAADAppServicePrincipalId, resourceId: $selectedSPId, consentType: AllPrincipals)"
	}
}
elseif ($grantParams.consentType -eq "Principal")
{
	$grantParamsPrincipalId = $grantParams.principalId
	$existingOauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$HttpWithAADAppServicePrincipalId' and resourceId eq '$selectedSPId' and consentType eq 'Principal'" | Where-Object { $_.PrincipalId -eq $grantParamsPrincipalId }
	
	if($existingOauth2PermissionGrant)
	{
		Write-Warning "An existing oAuth2PermissionGrant object was found with the same key properties. (clientId: $HttpWithAADAppServicePrincipalId, resourceId: $selectedSPId, consentType: Principal, principalId: $grantParamsPrincipalId)"
	}
}

if($existingOauth2PermissionGrant)
{
	Write-Warning "This means that the existing oAuth2PermissionGrant object is about to be updated with the new parameters provided."
	Write-Warning "Existing permission grant:"
	$existingOauth2PermissionGrant | Format-Table -wrap -auto
	Write-Warning "New permission grant requested:"
	$grantParams | Format-Table -wrap -auto

	if($Host.UI.PromptForChoice("Confirm permission grant update", "Do you want to proceed and update the above permission grant?", ('&Yes', '&No'), 0) -eq 1)
	{
		Write-Warning "Execution terminated."
		Exit
	}

	Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existingOauth2PermissionGrant.Id -BodyParameter $grantParams
}
else
{
	if($Host.UI.PromptForChoice("Confirm permission grant creation", "Do you want to proceed and create the permission grant?", ('&Yes', '&No'), 0) -eq 1)
	{
		Write-Warning "Execution terminated."
		Exit
	}

	#New-MgOauth2PermissionGrant -BodyParameter $grantParams
    New-MgOauth2PermissionGrant -ClientId $grantParams.clientId -ConsentType $grantParams.consentType -PrincipalId $grantParams.principalId -ResourceId $grantParams.resourceId -Scope $grantParams.scope
}

Write-Host "A delegated permission grant was persisted with the following parameters:"
$grantParams | Format-Table -wrap -auto

# add Authorized client application

# get application
$aad_application = Get-AzADApplication -ApplicationId $selectedAppId

if (!$aad_application) {
	Write-Host "No application found with the specified appId: $selectedAppId"
	Exit
}

# get user_impersonation scope id
$user_impersonation_scope = $aad_application.Api.oauth2PermissionScope | Where-Object { $_.Value -eq "user_impersonation" }

if (!$user_impersonation_scope) {
	Write-Host "No user_impersonation scope found in the application."
	Exit
}

$user_impersonation_scope_id = $user_impersonation_scope.Id

# Update the application with the pre-authorized application
$aad_application.Api.preAuthorizedApplications += [Microsoft.Azure.Commands.ActiveDirectory.PSADPreAuthorizedApplication]@{
	ApplicationId = $HttpWithAADAppAppId
	DelegatedPermissionIds = @($user_impersonation_scope_id)
}

Update-AzADApplication -ApplicationId $selectedAppId -Api $aad_application.Api

Write-Host "The application with appId $selectedAppId has been updated with the pre-authorized application."

Disconnect-MgGraph
Write-Host "Script execution completed successfully"
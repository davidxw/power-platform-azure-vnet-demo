# Load the RevertSubnetInjection script
. "$PSScriptRoot\NewSubnetInjection.ps1"
. "$PSScriptRoot\RevertSubnetInjection.ps1"

$environmentId = "Default-cf7a4a08-6d30-40c8-bd52-d6f7494c0541"
$policyArmIdOld = "/subscriptions/68dfa90d-6200-4bc6-bdad-178344084a61/resourceGroups/power-platform-vnet2/providers/Microsoft.PowerPlatform/enterprisePolicies/pp-test2-policy"
$policyArmIdNew = "/subscriptions/68dfa90d-6200-4bc6-bdad-178344084a61/resourceGroups/pp-vnet/providers/Microsoft.PowerPlatform/enterprisePolicies/pp-vnet-policy"

#RevertSubnetInjection -environmentId $environmentId `
#-policyArmId $policyArmIdOld

NewSubnetInjection -environmentId $environmentId `
                       -policyArmId $policyArmIdNew


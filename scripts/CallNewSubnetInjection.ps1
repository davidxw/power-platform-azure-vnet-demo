# Load the RevertSubnetInjection script
. "$PSScriptRoot\NewSubnetInjection.ps1"

# Call the RevertSubnetInjection function with the specified parameters
NewSubnetInjection -environmentId "Default-cf7a4a08-6d30-40c8-bd52-d6f7494c0541" `
                      -policyArmId "/subscriptions/68dfa90d-6200-4bc6-bdad-178344084a61/resourceGroups/power-platform-vnet2/providers/Microsoft.PowerPlatform/enterprisePolicies/pp-test2-policy"

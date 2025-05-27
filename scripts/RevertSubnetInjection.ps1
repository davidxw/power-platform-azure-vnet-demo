# Load thescript
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$environmentId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$policyArmId,

    [Parameter(Mandatory = $false)]
    [ValidateSet("tip1", "tip2", "prod")]
    [String]$endpoint

)
    
if (![bool]$endpoint) {
    $endpoint = "prod"
}

. "$PSScriptRoot\Common\EnvironmentEnterprisePolicyOperations.ps1"

Write-Host "Unlinking policy $policyArmId from environment $environmentId with endpoint $endpoint"

UnLinkPolicyFromEnv -policyType vnet -environmentId $environmentId -policyArmId $policyArmId -endpoint $endpoint 


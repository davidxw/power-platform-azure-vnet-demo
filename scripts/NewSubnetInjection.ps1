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

# Load thescript
. "$PSScriptRoot\Common\EnvironmentEnterprisePolicyOperations.ps1"

if (![bool]$endpoint) {
    $endpoint = "prod"
}

Write-Host "Linking policy $policyArmId to environment $environmentId with endpoint $endpoint"

LinkPolicyToEnv -policyType vnet -environmentId $environmentId -policyArmId $policyArmId -endpoint $endpoint 

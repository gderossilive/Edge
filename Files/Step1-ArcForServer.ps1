param(
    [string] $SubscriptionId,
    [string] $TenantId,
    [string] $ResourceGroupName,
    [string] $Location,
    [string] $ServicePrincipalId,
    [string] $Password,
    [string] $AAPLS,
    [string] $Proxy
)

# Enable an Azure VM to be ARC enabled
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose

New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# Set the proxy to download the package
$servicePrincipalClientId=$ServicePrincipalId;
$servicePrincipalSecret=$Password;
$env:SUBSCRIPTION_ID = $SubscriptionId;
$env:RESOURCE_GROUP = $ResourceGroupName;
$env:TENANT_ID = $TenantId;
$env:LOCATION = $Location;
$env:AUTH_TYPE = "token";
$env:CORRELATION_ID = "e0abc3e6-4247-4774-abc7-a6c7fc02de59";
$env:CLOUD = "AzureCloud";

# Download the package
if ($Proxy) {
    Invoke-WebRequest -proxy $Proxy -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi
} else {
    Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi 
}
#Invoke-WebRequest -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1" -Proxy $proxy
#Invoke-WebRequest -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1" -Proxy $proxy

# Install the package
#Write-Verbose -Message "Installing agent package" -Verbose
#& "$env:TEMP\install_windows_azcmagent.ps1"
(Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "AzureConnectedMachineAgent.msi" , "/l*v", "installationlog.txt", "/qn") -Wait -Passthru).ExitCode
#if ($exitCode -ne 0) {
#    $message = (net helpmsg $exitCode)        
#    $errorcode="AZCM0149"
#    throw "Installation failed: $message See installationlog.txt for additional details."
#}

if ($AAPLS) {
    $env:PRIVATELINKSCOPE = $AAPLS
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set proxy.url $Proxy
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set proxy.bypass "Arc"
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --service-principal-id "$servicePrincipalClientId" `
        --service-principal-secret "$servicePrincipalSecret" `
        --resource-group "$env:RESOURCE_GROUP" `
        --tenant-id "$env:TENANT_ID" `
        --location "$env:LOCATION" `
        --subscription-id "$env:SUBSCRIPTION_ID" `
        --cloud "$env:CLOUD" `
        --private-link-scope "$env:PRIVATELINKSCOPE" `
        --correlation-id "$env:CORRELATION_ID"
} else {
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --service-principal-id "$servicePrincipalClientId" `
        --service-principal-secret "$servicePrincipalSecret" `
        --resource-group "$env:RESOURCE_GROUP" `
        --tenant-id "$env:TENANT_ID" `
        --location "$env:LOCATION" `
        --subscription-id "$env:SUBSCRIPTION_ID" `
        --cloud "$env:CLOUD" `
        --correlation-id "$env:CORRELATION_ID"
}
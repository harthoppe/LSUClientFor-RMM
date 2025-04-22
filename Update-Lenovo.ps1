# utilizes LSUClient with adjustments for NinjaOne RMM interactivity

try {
    $batteryStatus = Get-WmiObject -Class BatteryStatus -Namespace root\wmi
    if ($batteryStatus.PowerOnLine -eq $false) {
        Write-Host "Power is not connected. Exiting script."
        exit 0
    }
} catch {
    Write-Host "Error checking power status. Exiting script."
    exit 0
}

Install-Module -Name 'LSUClient' -Force

# Sets a time limit for how long package installers can run before they're forcefully stopped.
# As a safety measure this limit is not applied for installers of firmware or BIOS/UEFI updates.
if ($env:maxInstallerRuntime) {
    Set-LSUClientConfiguration -MaxInstallerRuntime (New-TimeSpan -Minutes 6) -Verbose
}

# Set a maximum allowed installer runtime of 20 minutes
if ($env:maxExtractRuntime) {
    Set-LSUClientConfiguration -MaxExtractRuntime (New-TimeSpan -Minutes 20) -Verbose
}

for ($Round = 1; $Round -le $($env:maxRounds); $Round++) {
    Write-Host "Starting round $Round"
    $updates = Get-LSUpdate -FailUnsupportedDependencies -Verbose
    Write-Host "$($updates.Count) updates found"
    if ($updates.Count -eq 0) {
        break;
    }
    $updates | Save-LSUpdate  -Path $env:TEMP -Verbose
    [array]$results = Install-LSUpdate -Path $env:TEMP -Package $updates -Verbose
}

# Either restart the computer or display a remediation message
if ($env:forceRestartComputer -eq $true) {
    Restart-Computer
}  else {
    msg * "Critical updates have been installed. Please restart your computer immedietly to complete the installation."
}
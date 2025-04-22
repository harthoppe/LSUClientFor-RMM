# utilizes LSUClient with adjustments for NinjaOne RMM interactivity

# start logging
Start-Transcript -Path $env:TEMP\Update-LenovoComputer_NinjaOne.log -Append
Write-Host "Logging to $env:TEMP`\Update-LenovoComputer_NinjaOne.log"

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

# Install updates that are not firmware or BIOS/UEFI updates
Write-Host "Installing updates that are not firmware or BIOS/UEFI updates..."
Get-LSUpdate | Where-Object { $_.Installer.Unattended } | Tee-Object -Variable updates
Write-Host "$($unattendedUpdates.Count) updates found"
$unattendedUpdates | fl *
$unattendedUpdates | Save-LSUpdate -Verbose
$i = 1
foreach ($update in $unattendedUpdates) {
    Write-Host "Installing update $i of $($unattendedUpdates.Count): $($unattendedUpdates.Title)"
    Install-LSUpdate -Package $update -Verbose
    $i++
}

# Install firmware or BIOS/UEFI updates
# Note: The installer for firmware or BIOS/UEFI updates is not unattended, so it will prompt the user for input.
Write-Host "Installing firmware or BIOS/UEFI updates..."
Get-LSUpdate | Tee-Object -Variable updates
Write-Host "$($biosUpdates.Count) updates found"
$biosUpdates | fl *
$biosUpdates | Save-LSUpdate -Verbose
foreach ($update in $biosUpdates) {
    Write-Host "Installing update $i of $($biosUpdates.Count): $($biosUpdates.Title)"
    Install-LSUpdate -Package $update -Verbose
    $i++
}

# Either restart the computer or display a remediation message
if ($env:forceRestartComputer -eq $true) {
    Write-Host "Force restarting computer..."
    Stop-Transcript
    Restart-Computer
}  else {
    msg * "Critical updates have been installed. Please restart your computer immedietly to complete the installation."
    Stop-Transcript
}
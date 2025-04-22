# utilizes LSUClient with adjustments for NinjaOne RMM interactivity

# start logging
Start-Transcript -Path $env:TEMP\Update-LenovoComputer_NinjaOne.log -Append

try {
    $batteryStatus = Get-CimInstance -ClassName BatteryStatus -Namespace root\wmi
    if ($batteryStatus.PowerOnLine -eq $false) {
        Write-Host "Power is not connected. Exiting script." -BackgroundColor Red -ForegroundColor White
        Stop-Transcript
        exit 0
    }
} catch {
    Write-Host "Error checking power status. Exiting script." -BackgroundColor Red -ForegroundColor White
    Stop-Transcript
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
Write-Host "Finding updates that are not firmware or BIOS/UEFI updates..."
Get-LSUpdate | Where-Object { $_.Installer.Unattended } | Tee-Object -Variable unattendedUpdates
Write-Host "$($unattendedUpdates.Count) updates found"
if ($unattendedUpdates.Count -gt 0) {
    $unattendedUpdates | Save-LSUpdate -Verbose
    $i = 1
    foreach ($update in $unattendedUpdates) {
        Write-Host "Installing update $i of $($unattendedUpdates.Count): $($update.Title)"
        Install-LSUpdate -Package $update -Verbose
        $i++
    }
} else {
    Write-Host "No unattended updates found."
}

# Install firmware or BIOS/UEFI updates
# Note: The installer for firmware or BIOS/UEFI updates is not unattended, so it will prompt the user for input.
Write-Host "Finding firmware or BIOS/UEFI updates..."
Get-LSUpdate | Tee-Object -Variable biosUpdates
Write-Host "$($biosUpdates.Count) updates found"
if ($biosUpdates.Count -gt 0) {
    $biosUpdates | Save-LSUpdate -Verbose
    foreach ($update in $biosUpdates) {
        Write-Host "Installing update $i of $($biosUpdates.Count): $($update.Title)"
        Install-LSUpdate -Package $update -Verbose
        $i++
    }
} else {
    Write-Host "No firmware or BIOS/UEFI updates found."
}

# no updates found, exit script
if ($unattendedUpdates.Count -eq 0 -and $biosUpdates.Count -eq 0) {
    Write-Host "No updates found. Exiting script."
    exit 0
}

# Either restart the computer or display a remediation message
if ($env:forceRestartComputer -eq $true) {
    Write-Host "Force restarting computer..."
    Stop-Transcript
    Restart-Computer
}  else {
    msg * "Critical updates have been installed. Please restart your computer immediately to complete the installation."
    Stop-Transcript
}
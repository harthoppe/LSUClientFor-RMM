# utilizes LSUClient with adjustments for NinjaOne RMM interactivity

Start-Transcript -Path "$($env:TEMP)\Update-Lenovo.txt" -Append

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

# Set a maximum allowed installer runtime of 20 minutes if set by NinjaOne
$MaxRounds = $($env:maxRounds)

for ($Round = 1; $Round -le $MaxRounds; $Round++) {
    Write-Host "Starting round $Round"
    $updates = Get-LSUpdate -FailUnsupportedDependencies -Verbose
    Write-Host "$($updates.Count) updates found"
    if ($updates.Count -eq 0) {
        break;
    }
    $updates | Save-LSUpdate  -Path $env:TEMP -Verbose -ShowProgress
    [array]$results = Install-LSUpdate -Path $env:TEMP -Package $updates -SaveBIOSUpdateInfoToRegistry -Verbose
}

# Reboot if needed, by force if selected in NInjaOne
if ($env:rebootIfNeeded -eq 'true') {
    # force restart if requested
    try{
        $action = Get-ItemPropertyValue 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded' -ErrorAction SilentlyContinue
    }
    catch{}
    if($action -like 'reboot'){
        Remove-ItemProperty -Path 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded'
        Write-Output "Reboot requested"
        msg * "Lenovo updates have been installed. Your computer will nwo reboot."
        Restart-Computer
    }
    else {
        Write-Output "Reboot not required"
        msg * "Lenovo updates have been installed. No reboot is required."
    }
} elseif ($env:rebootIfNeeded -eq 'false') {
    # request restart if requested
    try{
        $action = Get-ItemPropertyValue 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded' -ErrorAction SilentlyContinue
    }
    catch{}
    if($action -like 'reboot'){
        Remove-ItemProperty -Path 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded'
        msg * "Updates have been installed that require reboot. Please restart your computer immedietly to complete installation."
    }
    else {
        Write-Output "Reboot not required"
        msg * "Lenovo updates have been installed. No reboot is required."
    }
}

Stop-Transcript
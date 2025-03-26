Start-Transcript -Path $env:TEMP -Append

Install-Module -Name 'LSUClient' # -Force

# Sets a time limit for how long package installers can run before they're forcefully stopped.
# As a safety measure this limit is not applied for installers of firmware or BIOS/UEFI updates.
if ($env:maxInstallerRuntime) {
    Set-LSUClientConfiguration -MaxInstallerRuntime (New-TimeSpan -Minutes 6) -Verbose
}

# Set a maximum allowed installer runtime of 20 minutes
if ($env:maxExtractRuntime) {
    Set-LSUClientConfiguration -MaxExtractRuntime (New-TimeSpan -Minutes 20) -Verbose
}

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

if ($env:rebootIfNeeded -eq 'true') {
    # restart if requested
    try{
        $action = Get-ItemPropertyValue 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded' -ErrorAction SilentlyContinue
    }
    catch{}
    if($action -like 'reboot'){
        shutdown.exe /r /t 240
        Remove-ItemProperty -Path 'HKLM:\Software\LSUClient\BIOSUpdate' -Name 'ActionNeeded'
        Write-Output "Reboot requested"
    }
    else{
        Write-Output "Reboot not required"
    }
}

Stop-Transcript
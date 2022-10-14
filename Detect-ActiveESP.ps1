<#
Version: 1.0
Author:  Oliver Kieselbach
Script:  Detect-ActiveESP.ps1
Date:    10/13/2022

Description:
Check if Enrollment Status Page (ESP) is still active or not.

Release notes:
Version 1.0: Original published version.

The script is provided "AS IS" with no warranties.
#>

# get the WWA Host container process for UWP apps to run jscript
$proc = Get-Process -Name WWAHost -ErrorAction SilentlyContinue

# Process not found, so ESP is not running
if ($null -eq $proc) {
    Write-Output "ESP-not-active"
    exit 0
}

# check if WWAHost has the CloudExperienceHost Module loaded, indicator for the ESP
if (-not ($proc.Modules -match 'CloudExperienceHost')) {
    Write-Output "ESP-not-active"
    exit 0
}

# check if the WWAHost process has an active Window handle, with 0 no Window 
# is available and ESP is not showing the full screen Window anymore
if($proc.MainWindowHandle -ne 0) {
    Write-Output "ESP-active"
    exit 0
} else {
    Write-Output "ESP-not-active"
    exit 0
}
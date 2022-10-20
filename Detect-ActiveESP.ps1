<#
Version: 1.1
Author:  Oliver Kieselbach
Script:  Detect-ActiveESP.ps1
Date:    10/20/2022

Description:
Check if Enrollment Status Page (ESP) is still active or not.

Release notes:
Version 1.0: Original published version.
Version 1.1: added safety check as @tjmklaver proposed in a comment on my BitLocker PIN blog post

The script is provided "AS IS" with no warranties.
#>

# get the WWA Host container process for UWP apps to run JScript
$proc = Get-Process -Name WWAHost -ErrorAction SilentlyContinue

# Process not found, so ESP is not running
if ($null -eq $proc) {
    Write-Output "ESP-not-active"
    exit 0
}

# check if WWAHost has the CloudExperienceHost Module loaded, an indicator for the ESP
if (-not ($proc.Modules -match 'CloudExperienceHost')) {
    Write-Output "ESP-not-active"
    exit 0
}

# check if the WWAHost process has an active Window handle, with 0 no Window 
# is available and ESP is not showing the full-screen Window anymore, the second check 
# in addition, the Responding attribute, determines if the process is responding to user input
if($proc.MainWindowHandle -ne 0 -or $proc.Responding -eq $true) {
    Write-Output "ESP-active"
    exit 0
} else {
    Write-Output "ESP-not-active"
    exit 0
}
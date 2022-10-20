<#
Version: 1.1
Author:  Oliver Kieselbach
Script:  Detect-ActiveESP.ps1
Date:    10/20/2022

Description:
Check if Enrollment Status Page (ESP) is still active or not.

Release notes:
Version 1.0: Original published version.
Version 1.1: Changed to check Security Systray Icon

The script is provided "AS IS" with no warranties.
#>

# Make sure Hide Systray ist NOT set to 1 !!
# HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray\HideSystray = 1

# get the "Windows Security notification icon" process, as this process is first started when 
# the explorer.exe processes the startup of the logged on user.
$proc = Get-Process -Name SecurityHealthSystray -ErrorAction SilentlyContinue

# Process not found, so ESP is not running
if ($null -ne $proc) {
    Write-Output "ESP-not-active"
    exit 0
} else {
    Write-Output "ESP-active"
    exit 0
}
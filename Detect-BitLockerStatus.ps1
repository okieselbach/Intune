<#
Version: 1.0
Author:  Oliver Kieselbach
Script:  Detect-BitLockerStatus.ps1
Date:    10/13/2022

Description:
Check if BitLocker Protection is turned on of off.

Release notes:
Version 1.0: Original published version.

The script is provided "AS IS" with no warranties.
#>

if ($(Get-BitLockerVolume -MountPoint 'C:').ProtectionStatus -eq 'On') {
    Write-Output "BitLockerProtection-On"
    exit 0
} else {
    Write-Output "BitLockerProtection-Off"
    exit 0
}
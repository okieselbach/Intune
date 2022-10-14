<#
Version: 1.0
Author:  Oliver Kieselbach
Script:  Detect-ActiveESP.ps1
Date:    10/13/2022

Description:
Check if RealmJoin ESP is still active or not.

Release notes:
Version 1.0: Original published version.

The script is provided "AS IS" with no warranties.
#>

$proc = Get-Process -Name RealmJoin -ErrorAction SilentlyContinue

if($proc.MainWindowHandle -ne 0) {
    Write-Output "RJ-ESP-active"
    exit 0
} else {
    Write-Output "RJ-ESP-not-active"
    exit 0
}
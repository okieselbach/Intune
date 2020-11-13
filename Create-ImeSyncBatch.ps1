<#
Version: 1.0
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: Create-SyncBatch.ps1

Description:
Create a imesync batch file for easy Intune Managmeent Extension (IME) sync trigger.

Release notes:
Version 1.0: Original published version. 

The script is provided "AS IS" with no warranties.
#>

$content = "powershell -Ex bypass -Command `"& {`$Shell = New-Object -ComObject Shell.Application ; `$Shell.open('intunemanagementextension://syncapp')}`""
Out-File -FilePath "$env:windir\System32\imesync.cmd" -Encoding ascii -InputObject $content -Force:$true
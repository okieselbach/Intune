<#
Version: 1.0
Author:  Oliver Kieselbach (oliverkieselbach.com)

Description:
Uninstall BGInfo64. User has to switch background to the original one by his own.

Release notes:
Version 1.0: Original published version.

The script is provided "AS IS" with no warranties.
#>

Remove-Item -Path "C:\Program Files\BGInfo" -Recurse -Force -Confirm:$false
Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo.lnk" -Force -Confirm:$false

Return 0
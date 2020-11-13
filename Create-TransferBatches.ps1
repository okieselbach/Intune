<#
Version: 1.0
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: Create-TransferBatches.ps1

Description:
Create tow batch files vor easy network share connect and disconnect.

Release notes:
Version 1.0: Original published version. 

The script is provided "AS IS" with no warranties.
#>

$content = "net use Z: \\192.168.1.1\Transfer$ /user:Administrator"
Out-File -FilePath "$env:windir\System32\connect.cmd" -Encoding ascii -InputObject $content -Force:$true

$content = "net use Z: /delete /y"
Out-File -FilePath "$env:windir\System32\disconnect.cmd"  -Encoding ascii -InputObject $content -Force:$true
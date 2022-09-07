####################################################

#region Initialization code

$m = Get-Module -Name Microsoft.Graph.Intune -ListAvailable
if (-not $m)
{
    Install-Module NuGet -Force
    Install-Module Microsoft.Graph.Intune
}
Import-Module Microsoft.Graph.Intune -Global

#endregion

####################################################

Function Get-DeviceHealthScripts(){
<#
.SYNOPSIS
Get all or individual Intune PowerShell Health scripts (aka Proactive Remediation scripts) and save them in specified folder.
 
.DESCRIPTION
The Get-DeviceHealthScripts cmdlet downloads all PowerShell Detection and Remediation scripts from Intune to a specified folder.
Initial Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER FolderPath
The folder where the PowerShell scripts are saved.

.EXAMPLE
Download all Intune PowerShell scripts to the specified folder

Get-DeviceHealthScripts -FolderPath C:\temp\HealthScripts
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $FolderPath
    )

    $graphApiVersion = "Beta"
    $graphUrl = "https://graph.microsoft.com/$graphApiVersion"

    $result = Invoke-MSGraphRequest -Url "$graphUrl/deviceManagement/deviceHealthScripts" -HttpMethod GET

    $scriptIds = $result.value | Select-Object id,displayName
    foreach($scriptId in $scriptIds){
        $script = Invoke-MSGraphRequest -Url "$graphUrl/deviceManagement/deviceHEalthScripts/$($scriptId.id)" -HttpMethod GET
        $healthScriptPath = Join-Path $FolderPath ($script.displayName)
        New-Item -Path $healthScriptPath -ItemType Directory
        if (($script.detectionScriptContent).Length -ne 0) {
            [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($script.detectionScriptContent))) | Out-File -Encoding ASCII -FilePath $(Join-Path $healthScriptPath "DetectionScript.ps1")
        }
        if (($script.remediationScriptContent).Length -ne 0) {
            [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($script.remediationScriptContent))) | Out-File -Encoding ASCII -FilePath $(Join-Path $healthScriptPath "RemediationScript.ps1")
        }
    }
}

Connect-MSGraph | Out-Null

Get-DeviceHealthScripts -FolderPath C:\temp\HealthScripts
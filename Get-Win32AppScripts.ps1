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

Function Get-Win32AppScripts() {
<#
.SYNOPSIS
Get all or Intune Win32App PowerShell Detection and Requirement scripts and save them in specified folder.
 
.DESCRIPTION
The Get-Win32AppScripts cmdlet downloads all Win32App PowerShell Detection and Requirement scripts from Intune to a specified folder.
Initial Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER FolderPath
The folder where the PowerShell scripts are saved.

.EXAMPLE
Download all Intune Win32App PowerShell Detection and Requirement scripts to the specified folder

Get-Win32AppScripts -FolderPath C:\temp\Win32AppScripts

.EXAMPLE
Download the Intune Win32App PowerShell Detection and Requirement scripts to the specified folder for a specified AppId

Get-Win32AppScripts -FolderPath C:\temp\Win32AppScripts -AppId 2cd64b95-dda3-4333-bcf1-6d9f3237ce73
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $FolderPath,
        [Parameter(Mandatory=$false)][String] $AppId
    )

    if ($AppId){
        $mobileApps = @()
        $mobileApp = Get-IntuneMobileApp -mobileAppId $AppId
        $mobileApps += $mobileApp
    }
    else {
        $mobileApps = Get-IntuneMobileApp -Filter "isof('microsoft.graph.win32LobApp')"
    }
    
    foreach($mobileApp in $mobileApps){
        $mobileAppScriptPath = Join-Path $FolderPath "$($mobileApp.id)_$($mobileApp.displayName)"

        # there can be several requirement scripts
        foreach($requirementRule in $mobileApp.requirementRules){
            if ($requirementRule."@odata.type" -eq "#microsoft.graph.win32LobAppPowerShellScriptRequirement"){
                Write-Host "Found [$($mobileApp.displayName)] RequirementRule: $($requirementRule.displayName)"
                New-Item -Path $mobileAppScriptPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                $reqRuleScriptName = $requirementRule.displayName
                if ($reqRuleScriptName -notmatch "\.ps1$"){
                    $reqRuleScriptName = "$reqRuleScriptName.ps1"
                }
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($requirementRule.scriptContent)) | Out-File -Encoding ASCII -FilePath $(Join-Path $mobileAppScriptPath $reqRuleScriptName) -Force
            }
        }

        # there can only be one Detection script
        if ($mobileApp.detectionRules.scriptContent.Length -ne 0){
            Write-Host "Found [$($mobileApp.displayName)] DetectionRule: DetectionScript.ps1"
            New-Item -Path $mobileAppScriptPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($mobileApp.detectionRules.scriptContent)) | Out-File -Encoding ASCII -FilePath $(Join-Path $mobileAppScriptPath "DetectionScript.ps1") -Force
        }
    }
}

Update-MSGraphEnvironment -Schema beta -Quiet | Out-Null
Connect-MSGraph | Out-Null

#Get-Win32AppScripts -FolderPath C:\Temp\Win32AppScripts -AppId 2cd64b95-dda3-4333-bcf1-6d9f3237ce73
Get-Win32AppScripts -FolderPath C:\Temp\Win32AppScripts
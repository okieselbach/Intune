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

Function Get-deviceShellScripts(){
<#
.SYNOPSIS
Get all or individual Intune PowerShell scripts and save them in specified folder.
 
.DESCRIPTION
The Get-deviceShellScripts cmdlet downloads all or individual PowerShell scripts from Intune to a specified folder.
Initial Author: Mark Stanfill (markstan@microsoft.com )
The script is provided "AS IS" with no warranties.
 
.PARAMETER FolderPath
The folder where the script(s) are saved.

.PARAMETER FileName
An optional parameter to specify an explicit PowerShell script to download.

.EXAMPLE
Download all Intune PowerShell scripts to the specified folder

Get-deviceShellScripts -FolderPath C:\temp 

.EXAMPLE
Download an individual PowerShell script to the specified folder

Get-deviceShellScripts -FolderPath C:\temp -FileName myScript.ps1

#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $FolderPath,
        [Parameter(Mandatory=$false)][String] $FileName
    )

    $graphApiVersion = "Beta"
    $graphUrl = "https://graph.microsoft.com/$graphApiVersion"

    $result = Invoke-MSGraphRequest -Url "$graphUrl/deviceManagement/deviceShellScripts" -HttpMethod GET

 

    if ($FileName){
        $scriptIds = $result.value | Select-Object id,fileName | Where-Object -Property fileName -eq $FileName
        $script = Invoke-MSGraphRequest -Url "$graphUrl/deviceManagement/deviceShellScripts/$($scriptId.id)" -HttpMethod GET
        [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($script.scriptContent))) | Out-File -Encoding ASCII -FilePath $(Join-Path $FolderPath $($script.fileName))
    }
    else{
        $scriptIds = $result.value | Select-Object id,fileName
        foreach($scriptId in $scriptIds){
            $script = Invoke-MSGraphRequest -Url "$graphUrl/deviceManagement/deviceShellScripts/$($scriptId.id)" -HttpMethod GET
            [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($script.scriptContent))) | Out-File -Encoding ASCII -FilePath $(Join-Path $FolderPath $($script.fileName))
        }
    }
}

Connect-MSGraph | Out-Null

# change folder as needed
Get-deviceShellScripts -FolderPath C:\temp\scripts
 
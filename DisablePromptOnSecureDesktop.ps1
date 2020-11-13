<#
Version: 1.0
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: DisablePromptOnSecureDesktop.ps1

Description:
The script disables the UAC prompt on the secure desktop. 
The deactivation enables tools like Quick Assist to work with elevation (UAC) prompts.

Release notes:
Version 1.0: Original published version. 

The script is provided "AS IS" with no warranties.
#>

$PromptOnSecureDesktop = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).PromptOnSecureDesktop

if ($PromptOnSecureDesktop -ne 0) {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
    $registryKey = "PromptOnSecureDesktop"
    $registryValue = 0
    
    try
    {
        Set-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -ErrorAction Stop
        $exitCode = 0
    }
    catch
    {   
        Write-Error -Message "Could not write regsitry value" -Category OperationStopped
        $exitCode = -1
    }
}

exit $exitCode
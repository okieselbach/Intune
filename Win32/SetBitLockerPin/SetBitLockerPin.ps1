# Author: Oliver Kieselbach (oliverkieselbach.com)
# Date: 08/01/2019
# Description: Starts the Windows Forms Dialog for BitLocker PIN entry and receives the PIN via exit code to set the additional key protector
# - 10/21/2019 changed PIN handover
 
# The script is provided "AS IS" with no warranties.

.\ServiceUI.exe -process:Explorer.exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -Ex bypass -file "$PSScriptRoot\Popup.ps1"
$exitCode = $LASTEXITCODE

$pathPINFile = $(Join-Path -Path $([Environment]::GetFolderPath("CommonDocuments")) -ChildPath "PIN-prompted.txt")

If ($exitCode -eq 0 -And (Test-Path -Path $pathPINFile)) { 
    $encodedText = Get-Content -Path $pathPINFile
    $PIN = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($encodedText))
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -Pin $(ConvertTo-SecureString $PIN -AsPlainText -Force) -TpmAndPinProtector
}

# Cleanup
Remove-Item -Path $pathPINFile -Force -ErrorAction SilentlyContinue
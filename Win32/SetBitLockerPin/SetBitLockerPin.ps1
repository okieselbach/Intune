# Author: Oliver Kieselbach (oliverkieselbach.com)
# Date: 08/01/2019
# Description: Starts the Windows Forms Dialog for BitLocker PIN entry and receives the PIN via exit code to set the additional key protector
 
# The script is provided "AS IS" with no warranties.

.\ServiceUI.exe -process:Explorer.exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -Ex bypass -file "$PSScriptRoot\Popup.ps1"
$PIN = $LASTEXITCODE
If ($PIN -gt 0) { 
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -Pin $(ConvertTo-SecureString $PIN -AsPlainText -Force) -TpmAndPinProtector
}
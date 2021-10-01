# Author: Oliver Kieselbach (oliverkieselbach.com)
# Date: 08/01/2019
# Description: Starts the Windows Forms Dialog for BitLocker PIN entry and receives the PIN via exit code to set the additional key protector
# - 10/21/2019 changed PIN handover
# - 02/10/2020 added content length check
# - 09/30/2021 changed PIN handover to AES encryption/decryption via DPAPI and shared key
#              added simple PIN check for incrementing and decrementing numbers e.g. 123456 and 654321
#              language support (see language.json), default is always en-US
#              changed temp storage location and temp file name
 
# The script is provided "AS IS" with no warranties.

.\ServiceUI.exe -process:Explorer.exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -Ex bypass -file "$PSScriptRoot\Popup.ps1"
$exitCode = $LASTEXITCODE

# ASR rules can block the write access to public documents so we use a writeable path for users and system
# check with sysinternals tool: accesschk.exe users -wus c:\windows\*
# "c:\windows\tracing" should be fine as temp storage
$pathPINFile = $(Join-Path -Path "$env:SystemRoot\tracing" -ChildPath "168ba6df825678e4da1a.tmp")

# Alternativly use public documents, but keep in mind the ASR rules!
#$pathPINFile = $(Join-Path -Path $([Environment]::GetFolderPath("CommonDocuments")) -ChildPath "168ba6df825678e4da1a.tmp")

If ($exitCode -eq 0 -And (Test-Path -Path $pathPINFile)) { 
    $encodedText = Get-Content -Path $pathPINFile
    if ($encodedText.Length -gt 0) {
        
        # using DPAPI with a random generated shared 256-bit key to decrypt the PIN
        $key = (43,155,164,59,21,127,28,43,81,18,198,145,127,51,72,55,39,23,228,166,146,237,41,131,176,14,4,67,230,81,212,214)
        $secure = ConvertTo-SecureString $encodedText -Key $key

        # code for PS7+
        #$PIN = ConvertFrom-SecureString -SecureString $secure -AsPlainText

        # code for PS5
        $PIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -Pin $(ConvertTo-SecureString $PIN -AsPlainText -Force) -TpmAndPinProtector
    }
}

# Cleanup
Remove-Item -Path $pathPINFile -Force -ErrorAction SilentlyContinue

# Author: Billy Collins (adminkb.com)
# Date: 12/06/2026
# Description: Removes BitLocker startup PIN and instead uses TPM unlock. Useful as an uninstall script for Oliver Kieselbach's SetBitLockerPin.ps1
 
# The script is provided "AS IS" with no warranties.

param(
    [string]$MountPoint = $env:SystemDrive
)

if (-not $MountPoint) {
    $MountPoint = 'C:'
}

try {
    $driveRoot = (Get-Item -Path $MountPoint -ErrorAction Stop).PSDrive.Root
}
catch {
    Write-Error ("Invalid mount point: {0}" -f $MountPoint)
    exit 1
}

try {
    $bitlocker = Get-BitLockerVolume -MountPoint $driveRoot -ErrorAction Stop
}
catch {
    Write-Error ("Unable to query BitLocker volume for {0}: {1}" -f $driveRoot, $_)
    exit 1
}

if ($bitlocker.ProtectionStatus -ne 'On') {
    Write-Output "BitLocker protection is not enabled on $driveRoot. Nothing to do."
    exit 0
}

# Add a TPM protector if one does not already exist.
$tpmProtector = $bitlocker.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
if (-not $tpmProtector) {
    Write-Output "Adding TPM protector to $driveRoot..."
    try {
        Add-BitLockerKeyProtector -MountPoint $driveRoot -TpmProtector -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to add TPM protector: $_"
        exit 1
    }
}
else {
    Write-Output "TPM protector already exists on $driveRoot."
}

# Remove startup PIN protectors after TPM is present.
$bitlocker = Get-BitLockerVolume -MountPoint $driveRoot -ErrorAction Stop
$pinProtectors = $bitlocker.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmAndPin' }
if ($pinProtectors) {
    foreach ($protector in $pinProtectors) {
        Write-Output "Removing PIN protector $($protector.KeyProtectorId) from $driveRoot..."
        Remove-BitLockerKeyProtector -MountPoint $driveRoot -KeyProtectorId $protector.KeyProtectorId -ErrorAction SilentlyContinue
    }
}
else {
    Write-Output "No TPM+PIN protectors found on $driveRoot."
}

Write-Output "Disable PIN logic completed for $driveRoot."

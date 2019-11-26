    $BitLockerVolume = Get-BitLockerVolume -MountPoint "C:"
    For ($i=0; $i -lt $BitLockerVolume.KeyProtector.Count; $i++) {
        if ($BitLockerVolume.KeyProtector[$i].KeyProtectorType -eq "TpmPin") {
            $KeyProtectorId = $BitLockerVolume.KeyProtector[$i].KeyProtectorId
        }
    }
    Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KeyProtectorId
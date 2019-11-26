$value = $(Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector | Where { $_.KeyProtectorType -eq 'TpmPin' }
if (-not $value) {
    Write-Output "No BitLocker Pin set"
}
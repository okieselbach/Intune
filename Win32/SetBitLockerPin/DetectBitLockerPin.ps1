$exitCode = 0
$DetectBitlockerPin = Write-Output $(Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector | Where { $_.KeyProtectorType -eq 'TpmPin' }
if ($DetectBitlockerPin){
    Write-Output "Done"
    exit $exitCode
}
else{
    $exitCode = 2
    exit $exitCode
}

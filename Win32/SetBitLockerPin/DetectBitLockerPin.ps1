#You probably should specify error code 2 as fail in "Specify return codes to indicate post-installation behavior"
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

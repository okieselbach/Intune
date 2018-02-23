$taskName = "RunCustomDOScript"
Stop-ScheduledTask -TaskName $taskName | Out-Null
if (Get-ScheduledTask -TaskName $taskName) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$customScriptsPath = $(Join-Path $env:ProgramData CustomScripts)
$dhcpOptionPath = "$customScriptsPath\DhcpOption.exe"
$doScriptPath = "$customScriptsPath\DOScript.ps1"
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"

if (Test-Path $dhcpOptionPath) {
    Remove-Item -Path $dhcpOptionPath -Force -Confirm:$false
}
if (Test-Path $doScriptPath) {
    Remove-Item -Path $doScriptPath -Force -Confirm:$false
}
if (Test-Path $registryPath) {
    Remove-Item -Path $registryPath -Force -Confirm:$false
}
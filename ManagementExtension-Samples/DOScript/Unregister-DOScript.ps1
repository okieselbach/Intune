<#
Version: 1.0
Author: Oliver Kieselbach
Script: Unregister-DOScript.ps1

Description:
Unregister the scheduled task and delete DO registry key

Release notes:
Version 1.0: Original published version. 

The script is provided "AS IS" with no warranties.
#>

$exitCode = 0

if (![System.Environment]::Is64BitProcess) {
    # start new PowerShell as x64 bit process, wait for it and gather exit code and standard error output
  $sysNativePowerShell = "$($PSHOME.ToLower().Replace("syswow64", "sysnative"))\powershell.exe"

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $sysNativePowerShell
  $pinfo.Arguments = "-ex bypass -file `"$PSCommandPath`""
  $pinfo.RedirectStandardError = $true
  $pinfo.RedirectStandardOutput = $true
  $pinfo.CreateNoWindow = $true
  $pinfo.UseShellExecute = $false
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $pinfo
  $p.Start() | Out-Null

  $exitCode = $p.ExitCode

  $stderr = $p.StandardError.ReadToEnd()

  if ($stderr) { Write-Error -Message $stderr }
}
else {
  # start logging to TEMP in file "scriptname".log
  Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" | Out-Null

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

  Stop-Transcript | Out-Null
}

exit $exitCode
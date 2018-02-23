<#
Version: 1.0
Author: Oliver Kieselbach
Script: Register-DOScript.ps1

Description:
Register a PS script as scheduled task to query DHCP for option 234 to get Group ID GUID

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

  # definition of PS script to query DHCP option ID 234 and write result to registry
  $scriptContent = @'
# With Windows 10 version 1803+ DOGroupIDSource can be set by MDM and Option ID 234 is queried natively by Windows!
# Due to this a version check is done to disable the solution when Windows 10 version 1803 is found.
# REMEMBER: as soon as 1803 is used the DOGroupIDSource must be set!
#
# https://docs.microsoft.com/en-us/windows/client-management/mdm/policy-csp-deliveryoptimization#deliveryoptimization-dogroupidsource
# DOGroupIDSource = 3 (DHCP Option ID)

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"

if ([int][Environment]::OSVersion.Version.Build -gt 16299) {
  Disable-ScheduledTask -TaskName "RunCustomDOScript" | Out-Null
  if (Test-Path $registryPath) {
    Remove-Item -Path $registryPath -Force -Confirm:$false
  }
}
else {
  $dhcpOptionTool = "DhcpOption.exe"
  $customScriptsPath = $(Join-Path $env:ProgramData CustomScripts)
  $filePath = "$customScriptsPath\$dhcpOptionTool"

  $optionId = 234

  $optionIdValue = Invoke-Expression -Command "$filePath $optionId"

  if (-not [string]::IsNullOrWhiteSpace($optionIdValue)) {
    if (!(Test-Path $registryPath)) {
        New-Item -Type String -Path $registryPath | Out-Null
    }
    $Name = "DOGroupId"
    $value = $optionIdValue
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType string -Force | Out-Null
  }
}
'@

  # Scheduled task XMl definition. Trigger on Logon and Workstation unlock
  $xmlTask = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Admin</Author>
    <Description>This script receives DO Group ID from DHCP Option ID 234 and writes value to registry.</Description>
    <URI>\RunCustomDOScript</URI>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>SessionUnlock</StateChange>
    </SessionStateChangeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ex bypass -file "C:\ProgramData\CustomScripts\DOScript.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
'@

  # we register the script only on pre 1803 Windows 10 versions.
  if ([int][Environment]::OSVersion.Version.Build -le 16299) {

    # create custom script folder and write PS script and dhcp option helper binary
    $customScriptsPath = $(Join-Path $env:ProgramData CustomScripts)
    if (!(Test-Path $customScriptsPath)) {
      New-Item -Path $customScriptsPath -ItemType Directory -Force -Confirm:$false
    }

    Out-File -FilePath "$customScriptsPath\DOScript.ps1" -InputObject $scriptContent -Encoding unicode -Force -Confirm:$false

    $dhcpOptionTool = "DhcpOption.exe"
    $dhcpOptionToolPath = "$customScriptsPath\$dhcpOptionTool"

    if (Test-Path $dhcpOptionToolPath) {
      Remove-Item -Path $dhcpOptionToolPath -Force -Confirm:$false
    }

    try {
      # get DhcpOption.exe from Azure Blob storage
      $url = "https://gktatooineblobs.blob.core.windows.net/resources/DhcpOption.exe"
      $ProgressPreference = 0
      Invoke-WebRequest $url -OutFile $dhcpOptionToolPath -UseBasicParsing

      $taskName = "RunCustomDOScript"
      Register-ScheduledTask -TaskName $taskName -Xml $xmlTask -Force
      Start-ScheduledTask -TaskName $taskName | Out-Null
    }
    catch {
      Write-Error -Message "Could not write regsitry value" -Category OperationStopped
    }
  }

  Stop-Transcript | Out-Null
}

exit $exitCode
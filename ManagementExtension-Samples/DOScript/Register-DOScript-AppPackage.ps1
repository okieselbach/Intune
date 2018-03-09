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
    $value = $optionIdValue.SubString(0, $optionIdValue.Length - 1)
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType string -Force | Out-Null
  }
}
'@

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
  Copy-Item -Path ".\$dhcpOptionTool" -Destination $dhcpOptionToolPath -Force -Confirm:$false

  $taskName = "RunCustomDOScript"
  Register-ScheduledTask -TaskName $taskName -Xml $xmlTask -Force
  Start-ScheduledTask -TaskName $taskName | Out-Null
}
<#
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: Create-CmtraceMRU.ps1
The script is provided "AS IS" with no warranties.
#>

# write cmtrace MRU list for SYSTEM user
& REG DELETE HKCU\Software\Microsoft\Trace32 /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "Register File Types" /t REG_SZ /d "1" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "Maximize" /t REG_SZ /d "1" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "Last Directory" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "MRU0" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "MRU1" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "MRU2" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Sensor.log" /f /reg:64 | Out-Null
& REG ADD HKCU\Software\Microsoft\Trace32 /v "MRU3" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\ClientHealth.log" /f /reg:64 | Out-Null

# as we run this early in the process during OOBE as SYSTEM, there is the defaultuser* (it's not always defaultuser0 it can also be defaultuser1 etc.) 
# already used, so we write the MRU explicitly in the evaluated defaultuser* user hive to get our custom cmtrace MRU list in OOBE
$defaultUserXSid = (Get-WmiObject win32_userprofile | Select-Object LocalPath,SID | Where-Object LocalPath -like "$env:SystemDrive\users\defaultuser*").SID
& REG DELETE HKU\$defaultUserXSid\Software\Microsoft\Trace32 /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "Register File Types" /t REG_SZ /d "0" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "Maximize" /t REG_SZ /d "1" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "Last Directory" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "MRU0" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "MRU1" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "MRU2" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Sensor.log" /f /reg:64 | Out-Null
& REG ADD HKU\$defaultUserXSid\Software\Microsoft\Trace32 /v "MRU3" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\ClientHealth.log" /f /reg:64 | Out-Null

# Load default user ntuser.dat in tempDefault if not already loaded
$tempProfileName = "tempDefaultUser"
If (($profileLoaded = Test-Path Registry::HKEY_USERS\$tempProfileName) -eq $false) {
   & REG.EXE LOAD HKU\$tempProfileName "$env:SystemDrive\Users\Default\NTuser.dat" | Out-Null
}

# write cmtrace MRU list for default user
& REG DELETE HKU\$tempProfileName\Software\Microsoft\Trace32 /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "Register File Types" /t REG_SZ /d "1" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "Maximize" /t REG_SZ /d "1" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "Last Directory" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "MRU0" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "MRU1" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "MRU2" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Sensor.log" /f /reg:64 | Out-Null
& REG ADD HKU\$tempProfileName\Software\Microsoft\Trace32 /v "MRU3" /t REG_SZ /d "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\ClientHealth.log" /f /reg:64 | Out-Null

# Unload default user NTuser.dat        
If ($profileLoaded -eq $false) {
   [gc]::Collect()
   Start-Sleep 1
   & REG.EXE UNLOAD HKU\$tempProfileName | Out-Null
}

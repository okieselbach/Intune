<#Version: 1.0Author: Oliver Kieselbach (oliverkieselbach.com)Script: EnhanceIntuneAgentLogging.ps1Description:The script extends the Intune Management Extension (IME) log behavior. LogMaxSize    controls the amount of bytes of one log fileLogMaxHistroy controls the amount of files to keepRelease notes:Version 1.0: Original published version. The script is provided "AS IS" with no warranties.#>

# define log file size in bytes e.g. 4194304 byte -> 4096 KB -> 4 MB
$logMaxSize = 4194304

# define log files to keep
$logMaxHistory = 4

# create the registry key path for the IME agent
$regKeyFullPath = "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging"
New-Item -Path $regKeyFullPath -Force | Out-Null

# set value to define new size instead of the default 2 MB
Set-ItemProperty -Path $regKeyFullPath -Name "LogMaxSize" -Value $logMaxSize -Type String -Force

# set value to define new amount of logfiles to keep
Set-ItemProperty -Path $regKeyFullPath -Name "LogMaxHistory" -Value $logMaxHistory -Type String -Force
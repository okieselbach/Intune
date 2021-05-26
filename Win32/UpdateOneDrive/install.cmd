:: Author: Oliver Kieselbach
:: Date: 2021/05/20
:: Purpose: replace built in OneDrive installer with new binary

:: Build as .intunewin package
:: Detection rule: File exists > C:\Windows\SysWOW64\OneDriveSetupUpdate.log
:: Run everything in x64 context
:: Install command: cmd /c install.cmd
:: Assignment: All devices

:: Download latest release here:
:: https://support.microsoft.com/en-us/office/onedrive-release-notes-845dcf18-f921-435e-bf28-4e24b95e5fc0

takeown /f "C:\Windows\SysWOW64\OneDriveSetup.exe"
icacls "C:\Windows\SysWOW64\OneDriveSetup.exe" /q /inheritance:e /T /grant *S-1-5-18:(OI)(CI)F
powershell -ex bypass -command Unblock-File -Path %~dp0OneDriveSetup.exe
copy /y %~dp0OneDriveSetup.exe C:\Windows\SysWOW64\OneDriveSetup.exe
icacls C:\Windows\SysWOW64\OneDriveSetup.exe /setowner "NT SERVICE\TrustedInstaller"

@echo OneDrive setup updated on %date% %time% >C:\Windows\SysWOW64\OneDriveSetupUpdate.log
<#
Version: 1.0
Author:  Oliver Kieselbach (oliverkieselbach.com)

Description:
Install BGInfo64 with custom background scheme where hostname and logged on user incl. membership (Admin|User) is shown.
It is especially usefull when dealing with virtual test environments where different devices, users, and different
Autopilot profiles are used. It enhanced viability of hostname, username and available permissions of the user.

Thanks to Nick Hogarth for inspiring me with his initial version. I basically extended his solution.
His version can be found here: https://nhogarth.net/2018/12/14/intune-win32-app-deploying-bginfo/

Release notes:
Version 1.0: Original published version.
Version 1.1: Fix output to use ascii

The script is provided "AS IS" with no warranties.
#>

New-Item -ItemType Directory -Force -Path "c:\Program Files\BGInfo" | Out-Null
#Start-BitsTransfer -Source "https://live.sysinternals.com/Bginfo64.exe" -Destination "C:\Program Files\BGInfo"
Copy-Item -Path "$PSScriptRoot\Bginfo64.exe" -Destination "C:\Program Files\BGInfo\Bginfo64.exe"
Copy-Item -Path "$PSScriptRoot\custom.bgi" -Destination "C:\Program Files\BGInfo\custom.bgi"

$Shell = New-Object -ComObject ("WScript.Shell")
$ShortCut = $Shell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo.lnk")
$ShortCut.TargetPath="`"C:\Program Files\BGInfo\Bginfo64.exe`""
$ShortCut.Arguments="`"C:\Program Files\BGInfo\custom.bgi`" /timer:0 /silent /nolicprompt"
$ShortCut.IconLocation = "Bginfo64.exe, 0";
$ShortCut.Save()

$CheckAdminScript = @"
Dim WshShell, colItems, objItem, objGroup, objUser
Dim strUser, strAdministratorsGroup, bAdmin
bAdmin = False

On Error Resume Next
Set WshShell = CreateObject("WScript.Shell")
strUser = WshShell.ExpandEnvironmentStrings("%Username%")

winmgt = "winmgmts:{impersonationLevel=impersonate}!//"
Set colItems = GetObject(winmgt).ExecQuery("Select Name from Win32_Group where SID='S-1-5-32-544'",,48)

For Each objItem in colItems
	strAdministratorsGroup = objItem.Name
Next

Set objGroup = GetObject("WinNT://./" & strAdministratorsGroup)

For Each objUser in objGroup.Members
    If objUser.Name = strUser Then
         bAdmin = True
         Exit For
    End If
Next
On Error Goto 0

If bAdmin Then
	Echo "Admin"
Else
	Echo "User"
End If
"@

$CheckAdminScript | Out-File -FilePath "C:\Program Files\BGInfo\CheckAdmin.vbs" -Encoding ascii -Force -Confirm:$false

Return 0
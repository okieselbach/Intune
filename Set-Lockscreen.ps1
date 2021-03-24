function Set-Lockscreen
{
<#
.SYNOPSIS
PowerShell script to change the lock screen image.

.DESCRIPTION
PowerShell script to change the lock screen image with a provided image (full path)

Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.

# The script logic is completely done by Ben Nordick (https://superuser.com/users/380318/ben-n), all credits belong to him!
# https://superuser.com/questions/1341997/using-a-uwp-api-namespace-in-powershell 

.PARAMETER Path
Full path to your image file.

.EXAMPLE
    PS C:\> . .\Set-Lockscreen.ps1
    PS C:\> Set-Lockscreen -Path path-to-your-image.jpg
#>

    [CmdletBinding(DefaultParameterSetName='none')]
        Param (
            [Parameter(ParameterSetName='Path', Position=0)]
            [String]
            $Path     
        ) 

    [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

    Function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }

    Function AwaitAction($WinRtAction) {
        $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]
        $netTask = $asTask.Invoke($null, @($WinRtAction))
        $netTask.Wait(-1) | Out-Null
    }

    [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null

    $image = Await([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
    AwaitAction([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($image))
}
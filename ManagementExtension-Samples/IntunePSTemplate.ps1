# Author: Oliver Kieselbach
# Date: 02/10/2018
# Description: Intune Management Extension - PowerShell template with logging, error codes, and x64 PowerShell execution
 
# The script is provided "AS IS" with no warranties.

$exitCode = 0

if (![System.Environment]::Is64BitProcess)
{
    $sysNativePowerShell = "$($PSHOME.ToLower().Replace("syswow64", "sysnative"))\powershell.exe"

    # start new PowerShell as x64 bit process, wait for it and gather exit code
    $exitCode = $(Start-Process $sysNativePowerShell -ArgumentList "-ex bypass -file `"$PSCommandPath`"" -WindowStyle Hidden -Wait -PassThru).ExitCode
}
else
{
    # start logging to TEMP in file "scriptname".log
    Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))"

    # === variant 1 ===
    #
    # => use "-ErrorAction Stop" for the command-lets and catch in case of errors
    #
    # example:
    #
    # try
    # {
    #     Set-ItemProperty ... -ErrorAction Stop
    # }
    # catch
    # {
    #     $exitCode = -1
    # }

    # === variant 2 ===
    #
    # => use "-ErrorVariable err -ErrorAction SilentlyContinue" and catch error and check err variable
    #
    # example:
    #
    # Start-Process ... -ErrorVariable err -ErrorAction SilentlyContinue
    # if ($err)
    # {
    #     $exitCode = -1
    # }

    Stop-Transcript
}

exit $exitCode
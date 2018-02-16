<#
Version: 1.1
Author: Oliver Kieselbach
Script: IntunePSTemplate.ps1

Description:
Intune Management Extension - PowerShell script template with logging,
error codes, standard error output handling and x64 PowerShell execution.

Release notes:
Version 1.0: Original published version. 
Version 1.1: Added standard error output handling. 

The script is provided "AS IS" with no warranties.
#>

$exitCode = 0

if (![System.Environment]::Is64BitProcess)
{
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
else
{
    # start logging to TEMP in file "scriptname".log
    Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" | Out-Null

    # === variant 1: use try/catch with ErrorAction stop -> use write-error to signal Intune failed execution
    # example:
    # try
    # {
    #     Set-ItemProperty ... -ErrorAction Stop
    # }
    # catch
    # {   
    #     Write-Error -Message "Could not write regsitry value" -Category OperationStopped
    #     $exitCode = -1
    # }

    # === variant 2: ErrorVariable and check error variable -> use write-error to signal Intune failed execution
    # example:
    # Start-Process ... -ErrorVariable err -ErrorAction SilentlyContinue
    # if ($err)
    # {
    #     Write-Error -Message "Could not write regsitry value" -Category OperationStopped
    #     $exitCode = -1
    # }

    Stop-Transcript | Out-Null
}

exit $exitCode
# Author: Oliver Kieselbach
# Date: 11/28/2017
# Description: Write to registry and ensure execution from x64 process environment.
 
# The script is provided "AS IS" with no warranties.
 
Param([switch]$Is64Bit = $false)
 
Function Restart-As64BitProcess {
    If ([System.Environment]::Is64BitProcess) { return }
    $Invocation = $($MyInvocation.PSCommandPath)
    if ($Invocation -eq $null) { return }
    $sysNativePath = $psHome.ToLower().Replace("syswow64", "sysnative")
    Start-Process "$sysNativePath\powershell.exe" -ArgumentList "-ex bypass -file `"$Invocation`" -Is64Bit" -WindowStyle Hidden -Wait
}
 
Function New-RegistryKey {
    Param([Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [ValidateSet("String", "ExpandString", "Binary", "DWord", "Multistring", "QWord", ignorecase = $true)]
        [string]$Type = "String")
    try {
        $subkeys = $Key.split("\")
 
        foreach ($subkey in $subkeys) {
            $currentkey += ($subkey + '\')
            if (!(Test-Path $currentkey)) {
                New-Item -Type String -Path $currentkey | Out-Null
            }
        }
 
        Set-ItemProperty -Path $currentkey -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
    }
    catch [system.exception] {
        $message = "{0} threw an exception: `n{0}" -f $MyInvocation.MyCommand, $_.Exception.ToString()
        Write-Host $message
    }
}
 
if (!$Is64Bit) { Restart-As64BitProcess }
else {
    # Enable Potentially Unwanted Application protection
    New-RegistryKey -Key "hklm:\SOFTWARE\Microsoft\Windows Defender" -Name "PUAProtection" -Value "1" -Type DWord
}
<#
Version: 0.1
Author: Christoph Hannebauer (glueckkanja-gab)
Script: Request-ScepCert.ps1

Description:
Uses Windows-built-in dmcertinst.exe to create and submit a SCEP request.
The certificate is installed in the current user's MY store.

Release notes:
Version 0.1: Original published version as PoC.

The script is provided under the terms of the Unlicense (https://unlicense.org/).
#>

param(
    [Parameter(Mandatory=$true)]$ScepURL,
    [Parameter(Mandatory=$true)]$Challenge,
    [Parameter(Mandatory=$true)]$CAThumbprint,
    $Subject = "CN=Test Certificate"
)

### Create the basic properties for the request in registry
Set-Location "HKCU:\SOFTWARE\Microsoft\SCEP\MS DM Server"
mkdir static
Set-Location static
mkdir Install
Set-Location .\Install

# SCEP Server properties
Set-ItemProperty -Path . -Name ServerURL -Value $ScepURL
Set-ItemProperty -Path . -Name CAThumbprint -Value $CAThumbprint

# Certificate properties
Set-ItemProperty -Path . -Name SubjectName -Value $Subject
Set-ItemProperty -Path . -Name SubjectAlternativeNames -Value ""
Set-ItemProperty -Path . -Name KeyProtection -Value 2
Set-ItemProperty -Path . -Name EKUMapping -Value "1.3.6.1.5.5.7.3.2" # Client Authentication
Set-ItemProperty -Path . -Name KeyUsage -Value 0xa0 # Encrypt + Sign
Set-ItemProperty -Path . -Name KeyLength -Value 2048

Set-ItemProperty -Path . -Name ValidPeriod -Value "Years"
Set-ItemProperty -Path . -Name ValidPeriodUnits -Value 1

# Request behavior
Set-ItemProperty -Path . -Name RetryDelay -Value 1
Set-ItemProperty -Path . -Name RetryCount -Value 3
Set-ItemProperty -Path . -Name CurrentRetryCount -Value 1
Set-ItemProperty -Path . -Name CorrelationGuid -Value "{$([Guid]::NewGuid())}"
Set-ItemProperty -Path . -Name HashAlgorithm -Value "SHA-2"

# Unknown Purpose
Set-ItemProperty -Path . -Name Enroll -Value ""
Set-ItemProperty -Path . -Name TemplateName -Value ""


### Add the challenge to the request
Add-Type -AssemblyName System.Security # Required for DataProtection

$pwterm = New-Object Object[] ($Challenge.Length * 2 + 2) # times 2 for Unicode and then another 2 for the null terminator
$pwbin = [System.Text.Encoding]::Unicode.GetBytes($Challenge)
[array]::Copy($pwbin, $pwterm, $Challenge.Length * 2) # the last two bytes are not written and stay 0, i.e. a null terminator

# Write the Challenge to Registry
$scope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
$prot = [System.Security.Cryptography.ProtectedData]::Protect($pwterm, $null, $scope)
mkdir Challenge
Set-Location Challenge
Set-ItemProperty -Path . -Name Challenge -Value $prot


### Submit the request with dmcertinst.exe
Set-Location c:\windows\system32
.\dmcertinst.exe -s -k "Software\Microsoft\SCEP\MS DM Server\static\Install" -h HKCU -t static
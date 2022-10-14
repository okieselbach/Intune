<#
Version: 1.1
Author:  Oliver Kieselbach
Script:  Detect-PrimaryUser.ps1
Date:    10/13/2022

Description:
Check if logged on user is enrollment user which is also our primary user (primary user change is not supported)

Release notes:
Version 1.0: Original published version.
Version 1.1: renamed to Detect-PrimaryUser.ps1

The script is provided "AS IS" with no warranties.
#>

# UserEmail from CloudDomainJoin Info = Enrollment User
$PrimaryUserUPN = $null
$CloudDomainJoinInfo = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo" -ErrorAction SilentlyContinue
if ($null -ne $CloudDomainJoinInfo) {
    # Change of Primary User on Intune side is not reflected in registry as the registry key is the enrollment user and is not updated
    # UPN Change is also not reflected in registry -> not supported
    # Consequence: Change of Primary User or UPN change needs reinstall of device!

    $PrimaryUserUPN = ($CloudDomainJoinInfo | Get-ItemProperty).UserEmail
}

# Cloud PC has no Enrollment user (dummy entry fooUser@domain.com is written), so we always install (no Primary user support there)
$SystemProductName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name SystemProductName -ErrorAction SilentlyContinue).SystemProductName
if ($PrimaryUserUPN.ToLower().StartsWith("foouser@") -and $SystemProductName.ToLower().StartsWith("cloud pc")) {
    Write-Output "PrimaryUser"
    exit 0
}

# No CloudDomainJoinInfo available -> Autopilot Pre-Provisioning (aka White Glove) Phase
if ([string]::IsNullOrEmpty($PrimaryUserUPN)) {
    Write-Output "PrimaryUser"
    exit 0
}

# approach will not work with multisession currently, as there might be more than one explorer.exe
$explorerProcess = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
if ($explorerProcess.Count -ne 0) {
    $explorerOwner = $explorerProcess[0].GetOwner().User

    # explorer runs as defaultUser* or system -> OOBE phase
    if ($explorerOwner -contains "defaultuser" -or $explorerOwner -contains "system") {
        Write-Output "PrimaryUser"
        exit 0
    }

    # explorer runs as a normal user process, check if it is the current logged on user
    $userSid = (Get-ChildItem -Recurse "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache" | Get-ItemProperty | Where-Object { $_.SAMName -match $explorerOwner } | Select-Object -First 1 PSChildName).PSChildName
    $LoggedOnUserUPN = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$userSid\IdentityCache\$userSid" -Name UserName).UserName

    if ($PrimaryUserUPN -eq $LoggedOnUserUPN) {
        Write-Output "PrimaryUser"
        exit 0
    }
    else {
        Write-Output "SecondaryUser"
        exit 0
    }
}
else {
    # no explorer running -> OOBE phase
    Write-Output "PrimaryUser"
    exit 0
}
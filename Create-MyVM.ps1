<#
Version: 1.0
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: Create-MyVM.ps1

Description:
The script crates a VM on a Hyper-V host with TPM and starts it including the VMConnect client. 

Release notes:
Version 1.0: Original published version. 

The script is provided "AS IS" with no warranties.
#>

# ask some parameters like VM name, CPU count or latest Win10 or Insider
$VMName = Read-Host -Prompt 'Enter VM name'
if (($CPUCount = Read-Host -Prompt "CPU count? [default=4, Enter]") -eq "") { $CPUCount = 4 }
if (($Insider = Read-Host -Prompt "Insider? [default=no, Enter]") -eq "") { $Insider = $false }
else { $Insider = $true }

if (!$Insider) {
    $IsoPath = "D:\en_windows_10_business_editions_version_20h2_x64_dvd_4788fb7c.iso"
}
else {
    $IsoPath = "D:\20246.1.201024-2009.fe_release_CLIENT_BUSINESS_VOL_x64FRE_en-us.iso"
}

# some definitions for Network and VM storage path
$VMSwitchName = "Private (Class C)"
$VhdxPath = "V:\Hyper-V\Virtual Hard Disks\$VMName.vhdx"
$VMPath = "V:\Hyper-V\Virtual Machines"

# I'm not usign Enhanced Session Mode, so we can run this once to disable it on the host
#Set-VMHost -EnableEnhancedSessionMode $false

New-VM -Name $VMName -BootDevice VHD -NewVHDPath $VhdxPath -Path $VMPath -NewVHDSizeBytes 127GB -Generation 2 -Switch $VMSwitchName
Set-VM -VMName $VMName -ProcessorCount $CPUCount
Set-VMMemory -VMName $VMName -StartupBytes 2GB -MinimumBytes 512MB -MaximumBytes 1048576MB -DynamicMemoryEnabled $true
Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut $false
Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
Enable-VMTPM -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
Set-VMDvdDrive -VMName $VMName -Path $IsoPath
$bootorder = (Get-VMFirmware -VMName $VMName).BootOrder
Set-VMFirmware -VMName $VMName -BootOrder $bootorder[2],$bootorder[0],$bootorder[1]
Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"

# To test out stuff which relies on hypervisor etc. uncomment the following line
#Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true

Set-VMVideo -VMName $VMName -ResolutionType Single -HorizontalResolution 1920 -VerticalResolution 1080
# if a teh default is wanted use:
#Set-VMVideo -VMName $VMName -ResolutionType Default

# Start the CM right away and open the VMConnect window to directly inteact with the new VM
Start-VM -Name $VMName
VMConnect localhost $VMName
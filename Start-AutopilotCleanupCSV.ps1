# https://www.powershellgallery.com/packages/WindowsAutoPilotIntune
# https://github.com/microsoft/Intune-PowerShell-SDK

####################################################

#region Initialization code

$m = Get-Module -Name Microsoft.Graph.Intune -ListAvailable
if (-not $m)
{
    Install-Module NuGet -Force
    Install-Module Microsoft.Graph.Intune
}
Import-Module Microsoft.Graph.Intune -Global

#endregion

####################################################

Function Get-AutoPilotDevice(){
    <#
    .SYNOPSIS
    Gets devices currently registered with Windows Autopilot.
     
    .DESCRIPTION
    The Get-AutoPilotDevice cmdlet retrieves either the full list of devices registered with Windows Autopilot for the current Azure AD tenant, or a specific device if the ID of the device is specified.
     
    .PARAMETER id
    Optionally specifies the ID (GUID) for a specific Windows Autopilot device (which is typically returned after importing a new device)
     
    .PARAMETER serial
    Optionally specifies the serial number of the specific Windows Autopilot device to retrieve
     
    .PARAMETER expand
    Expand the properties of the device to include the Autopilot profile information
     
    .EXAMPLE
    Get a list of all devices registered with Windows Autopilot
     
    Get-AutoPilotDevice
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$True)] $id,
        [Parameter(Mandatory=$false)] $serial,
        [Parameter(Mandatory=$false)] [Switch]$expand = $false
    )

    Process {

        # Defining Variables
        $graphApiVersion = "beta"
        $Resource = "deviceManagement/windowsAutopilotDeviceIdentities"
    
        if ($id -and $expand) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$($id)?`$expand=deploymentProfile,intendedDeploymentProfile"
        }
        elseif ($id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
        }
        elseif ($serial) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=contains(serialNumber,'$serial')"
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        }
        try {
            $response = Invoke-MSGraphRequest -Url $uri -HttpMethod Get
            if ($id) {
                $response
            }
            else {
                $devices = $response.value
                $devicesNextLink = $response."@odata.nextLink"
    
                while ($devicesNextLink -ne $null){
                    $devicesResponse = (Invoke-MSGraphRequest -Url $devicesNextLink -HttpMethod Get)
                    $devicesNextLink = $devicesResponse."@odata.nextLink"
                    $devices += $devicesResponse.value
                }
    
                if ($expand) {
                    $devices | Get-AutopilotDevice -Expand
                }
                else
                {
                    $devices
                }
            }
        }
        catch {
            Write-Error $_.Exception 
            break
        }
    }
}

Function Invoke-AutopilotSync(){
    <#
    .SYNOPSIS
    Initiates a synchronization of Windows Autopilot devices between the Autopilot deployment service and Intune.
     
    .DESCRIPTION
    The Invoke-AutopilotSync cmdlet initiates a synchronization between the Autopilot deployment service and Intune.
    This can be done after importing new devices, to ensure that they appear in Intune in the list of registered
    Autopilot devices. See https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/api/intune_enrollment_windowsautopilotsettings_sync
    for more information.
     
    .EXAMPLE
    Initiate a synchronization.
     
    Invoke-AutopilotSync
    #>
    [cmdletbinding()]
    param
    (
    )
        # Defining Variables
        $graphApiVersion = "beta"
        $Resource = "deviceManagement/windowsAutopilotSettings/sync"
    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        try {
            Invoke-MSGraphRequest -Url $uri -HttpMethod Post
        }
        catch {
            Write-Error $_.Exception 
            break
        }
    
}

Function Start-AutopilotCleanupCSV(){
<#
.SYNOPSIS
Deletes a batch of existing Autopilot devices.
 
.DESCRIPTION
The Start-AutopilotCleanupCSV cmdlet processes a list of Autopilot device information and deletes them in Autopilot and optionally from Intune (contained in a CSV file with serial number, same file as used for import can be used). It is a convenient wrapper to handle the cleanup details. After the devices have been deleted from Autopilot and optionally from Intune, the cmdlet will report the status of the batch deletion request (the status represents the successfully transmitted deletion request, not if the device is actually deleted!). After the deletion request a Autopilot Sync and verification should be done. See Example 3 for details. The graph call to do the batch deletion request is based on https://docs.microsoft.com/en-us/graph/json-batching.
Initial Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER CsvFile
The file containing the list of serial numbers of the Autopilot devices to be deleted. CSV file with Autopilot device entries including the column 'Device Serial Number'.

.PARAMETER IntuneCleanup
An optional switch to include the deletion of the Intune managed device object.

.PARAMETER ShowCleanupRequestOnly
An optional switch to get the raw batch job deletion json definition. It is hidden by default from parameter intellisense. This is intended for debugging and a kind of -WhatIf to check if the correct deletion batch job Graph request is generated.
 
.EXAMPLE
Deletes a batch of devices from Windows Autopilot and Intune for the current Azure AD tenant.
 
Start-AutopilotCleanupCSV -CsvFile C:\Devices.csv

Device Serial Number             Deletion Request Status
--------------------             -----------------------
7243-2648-3107-2818-2556-6923-30                     200

.EXAMPLE
Start Autopilot device and Intune cleanup and re-check if the devices are deleted. Report not deleted devices serial numbers. If a device can't be deleted, try deleting it via https://businessstore.microsoft.com/en-us/manage/ as a fallback solution.

$CsvFile = "C:\Devices.csv"
Start-AutopilotCleanupCSV -CsvFile $CsvFile -IntuneCleanup

Write-Output "`nInvoking Autopilot sync..."
Start-Sleep -Seconds 10
Invoke-AutopilotSync

Write-Output "`nWaiting 60 seconds to re-check if devices are deleted..."
Start-Sleep -Seconds 60

# Check if all Autopilot devices are successfully deleted
$serialNumbers = Import-Csv $CsvFile | Select-Object -Unique 'Device Serial Number' | Select-Object -ExpandProperty 'Device Serial Number'

Write-Output "`nThese devices couldn't be deleted:"
foreach ($serialNumber in $serialNumbers){
    $device = Get-AutoPilotDevice -serial $serialNumber
    $device.serialNumber
}

Device Serial Number             Deletion Request Status
--------------------             -----------------------
7243-2648-3107-2818-2556-6923-30                     200
7851-2064-8105-4061-0737-2977-27                     400

Invoking Autopilot sync...

Waiting 60 seconds to re-check if devices are deleted...

These devices couldn't be deleted:
7851-2064-8105-4061-0737-2977-27
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $CsvFile,
        [Parameter(Mandatory=$false)][Switch] $IntuneCleanup,
        [Parameter(Mandatory=$false,DontShow)][Switch] $ShowCleanupRequestOnly
    )

    $graphApiVersion = "Beta"
    $graphUrl = "https://graph.microsoft.com/$graphApiVersion"

    # get all unique Device Serial Numbers from the CSV file (column must be named 'Device Serial Number')
    $serialNumbers = Import-Csv $CsvFile | Select-Object -Unique 'Device Serial Number' | Select-Object -ExpandProperty 'Device Serial Number'

    # collection for the batch job deletion requests
    $requests = @()

    # according to the docs the current max batch count is 20
    # https://github.com/microsoftgraph/microsoft-graph-docs/blob/master/concepts/known-issues.md#limit-on-batch-size
    $batchMaxCount = 20;
    $batchCount = 0

    if ($serialNumbers.Count -gt 0){
        # loop through all serialNumbers and build batches of requests with max of $batchMaxCount
        for ($i = 0; $i -le $serialNumbers.Count; $i++) {
            # reaches batch count or total requests invoke graph call
            if ($batchCount -eq $batchMaxCount -or $i -eq $serialNumbers.Count){
                if ($requests.count -gt 0){
                    # final deletion batch job request collection
                    $content = [pscustomobject]@{
                        requests = $requests
                    }
            
                    # convert request data to proper format for graph request 
                    $jsonContent = ConvertTo-Json $content -Compress
        
                    if ($ShowCleanupRequestOnly){
                        Write-Host $(ConvertTo-Json $content)
                    }
                    else{
                        try{
                            # delete the Autopilot devices as batch job
                            $result = Invoke-MSGraphRequest -Url "$graphUrl/`$batch" `
                                                            -HttpMethod POST `
                                                            -Content "$jsonContent"
                            
                            # display some deletion job request results (status=200 equals successfully transmitted, not successfully deleted!)
                            Write-Host 
                            $result.responses | Select-Object @{Name="Device Serial Number";Expression={$_.id}},@{Name="Deletion Request Status";Expression={$_.status}}
                            # according to the docs response might have a nextLink property in the batch response... I didn't saw this in this scenario so taking no care of it here
                        }
                        catch{
                            Write-Error $_.Exception 
                            break
                        }
                    }
                    # reset batch requests collection
                    $requests = @()
                    $batchCount = 0
                }
            }
            # add current serial number to request batch
            if ($i -ne $serialNumbers.Count){
                try{
                    # check if device with serial number exists otherwise it will be skipped
                    if ($serialNumbers.Count -eq 1) {
                        $serial = $serialNumbers
                    }
                    else {
                        $serial = $serialNumbers[$i]
                    }
                    $device = Get-AutoPilotDevice -serial $serial
    
                    if ($device.id){
                        # building the request batch job collection with the device id
                        $requests += [pscustomobject]@{
                            id = $serial
                            method = "DELETE"
                            url = "/deviceManagement/windowsAutopilotDeviceIdentities/$($device.id)"
                        }

                        # try to delete the managed Intune device object, otherwise the Autopilot record can't be deleted (enrolled devices can't be deleted)
                        # under normal circumstances the Intune device object should already be deleted, devices should be retired and wiped before off-lease or disposal
                        if ($IntuneCleanup -and -not $ShowCleanupRequestOnly){
                            Get-IntuneManagedDevice | Where-Object serialNumber -eq $serial | Remove-DeviceManagement_ManagedDevices

                            # enhancement option: delete AAD record as well
                            # side effect: all BitLocker keys will be lost, maybe delete the AAD record at later time separately
                        }
                    }
                    else{
                        Write-Host "$($serial) not found, skipping device entry"
                    }
                }
                catch{
                    Write-Error $_.Exception 
                    break
                }
            }
            $batchCount++
        }
    }
}


Connect-MSGraph | Out-Null

$CsvFile = "C:\temp\autopilot-devices.csv"
Start-AutopilotCleanupCSV -CsvFile $CsvFile

# I think the sync is not really necessary here. Should be reflected automatically without triggering the sync.
#Write-Output "`nInvoking Autopilot sync..."
#Start-Sleep -Seconds 15
#Invoke-AutopilotSync

Write-Output "`nWaiting 60 seconds to re-check if devices are deleted..."
Start-Sleep -Seconds 60

# Check if all Autopilot devices are successfully deleted
$serialNumbers = Import-Csv $CsvFile | Select-Object -Unique 'Device Serial Number' | Select-Object -ExpandProperty 'Device Serial Number'

Write-Output "`nThese devices couldn't be deleted (if no device is listed, everything went well):"
foreach ($serialNumber in $serialNumbers){
    $device = Get-AutoPilotDevice -serial $serialNumber
    $device.serialNumber
}

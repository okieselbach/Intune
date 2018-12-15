<#
.SYNOPSIS
Assigns an user to a Windows Autopilot device.

.DESCRIPTION
The Set-AutoPilotAssignUserToDevice cmdlet assign the specified user and sets a display name to show on the Windows Autopilot device.

.AUTHOR
Oliver Kieselbach (oliverkieselbach.com)

.PARAMETER id
The Windows Autopilot device id (mandatory).

.PARAMETER userPrincipalName
The user principal name (mandatory).

.PARAMETER displayName
The name to display during Windows Autopilot enrollment (mandatory).

.EXAMPLE
Assign an user and a name to display during enrollment to a Windows Autopilot device. 

Set-AutoPilotAssignUserToDevice -id $id -userPrincipalName $userPrincipalName -DisplayName "John Doe"
#>
Function Set-AutoPilotAssignUserToDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $id,
        [Parameter(Mandatory=$true)] $userPrincipalName,
        [Parameter(Mandatory=$true)] $displayName
    )
    
        # Defining Variables
        $graphApiVersion = "beta"
        $Resource = "deviceManagement/windowsAutopilotDeviceIdentities"
    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id/AssignUserToDevice"
        $json = @"
{
    "userPrincipalName":"$userPrincipalName",
    "addressableUserName":"$displayName"
}            
"@

        try {
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $json -ContentType "application/json"
        }
        catch {
    
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    
            Write-Host "Response content:`n$responseBody" -f Red
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    
            break
        }
    
    }
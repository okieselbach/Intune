function Convert-AzureAdObjectIdToSid {
<#
.SYNOPSIS
Convert a Object ID to SID
 
.DESCRIPTION
Converts a Azure AD Object ID to a SID
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The Object ID to convert
#>

    param([String] $ObjectId)

    $sourceArray = [Guid]::Parse($ObjectId).ToByteArray()
    $destinationArray = New-Object 'UInt32[]' 4

    [Buffer]::BlockCopy($sourceArray, 0, $destinationArray, 0, 16)
    $sid = "S-1-12-1-$destinationArray".Replace(' ', '-')

    return $sid
}

$objectId = "cc574217-b826-4fe3-91d8-a46ab069cedd"
$sid = Convert-AzureAdObjectIdToSid -ObjectId $objectId
Write-Output $sid

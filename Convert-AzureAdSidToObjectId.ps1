function Convert-AzureAdSidToObjectId {
<#
.SYNOPSIS
Convert a Azure AD SID to Object ID
 
.DESCRIPTION
Converts an Azure AD SID to Object ID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The SID to convert
#>

    param([String] $Sid)

    $text = $sid.Replace('S-1-12-1-', '')
    $array = [UInt32[]]$text.Split('-')

    $bytes = New-Object 'Byte[]' 16
    [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
    [Guid]$guid = $bytes

    return $guid
}


#$sid = "S-1-12-1-1484481183-1312765185-2161529533-2885338732" # Global Administrator role
#$sid = "S-1-12-1-1714650063-1279023240-2373304728-3448477032" # ADM_Workstations group
$sid = "S-1-12-1-3634333542-1146815947-1446741395-3659670604" # Azure AD Joined Device Local Administrator role
$objectId = Convert-AzureAdSidToObjectId -Sid $sid
Write-Output $objectId

# Output:

# Guid
# ----
# 73d664e4-0886-4a73-b745-c694da45ddb4
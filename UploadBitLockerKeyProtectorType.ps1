<#
.SYNOPSIS
Reads the BitLocker Key Protector Type for the OS drive und uploads to Azure table storage.

.DESCRIPTION
The script reads the BitLocker Key Protector Type for the OS Drive and uploads to Azure table storage.

The script is provided "AS IS" with no warranties.

.AUTHOR
Oliver Kieselbach (oliverkieselbach.com)

.EXAMPLE
UploadBitLockerKeyProtectorType.ps1
#>

$storageAccount = "" # fill here!!!
$sasToken = "" # fill here!!!

function Upload-BitLockerInfo($TableName, $PartitionKey, $RowKey, $entity) {  
    $version = "2017-04-17"
    $resource = "$tableName(PartitionKey='$PartitionKey',RowKey='$Rowkey')$sasToken"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource"
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $headers = @{
        'x-ms-date'    = $GMTTime
        "x-ms-version" = $version
        Accept         = "application/json;odata=fullmetadata"
    }
    $body = $entity | ConvertTo-Json
    Invoke-RestMethod -Method PUT -Uri $table_url -Headers $headers -Body $body -ContentType application/json
}

$KeyProtectorType = ""
$(Get-BitLockerVolume $env:SystemDrive).KeyProtector | ForEach-Object {
    if ($_.KeyProtectorType.ToString().ToLower().Contains("tpm")) {
        $KeyProtectorType = $_.KeyProtectorType.ToString()
    }
}
$body = @{
    RowKey               = $env:SystemDrive
    PartitionKey         = $env:COMPUTERNAME
    KeyProtectorType     = $KeyProtectorType
}
Upload-BitLockerInfo -TableName "BitLocker" -RowKey $body.RowKey -PartitionKey $body.PartitionKey -entity $body

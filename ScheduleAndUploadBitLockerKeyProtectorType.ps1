# Author: Oliver Kieselbach (oliverkieselbach.com)
# Date: 08/01/2019
# Description: install ps script and register scheduled task
 
# The script is provided "AS IS" with no warranties.
 
# define your PS script here
$content = @'
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
'@
 
# create custom folder and write PS script
$path = $(Join-Path $env:ProgramData CustomScripts)
if (!(Test-Path $path)) {
    New-Item -Path $path -ItemType Directory -Force -Confirm:$false
}
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\UploadBitLockerKeyProtectorType.ps1) -Encoding unicode -Force -InputObject $content -Confirm:$false
 
# register script as scheduled task
$Time = New-ScheduledTaskTrigger -At 12:00 -Daily
$User = "SYSTEM"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -file `"C:\ProgramData\CustomScripts\UploadBitLockerKeyProtectorType.ps1`""
Register-ScheduledTask -TaskName "UploadBitLockerKeyProtectorType" -Trigger $Time -User $User -Action $Action -Force
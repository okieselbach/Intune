$VMName = Read-Host -Prompt 'Enter VM name'
$FileName = Read-Host -Prompt 'Enter FileName'
Copy-VMFile $VMName -SourcePath "D:\$FileName" -DestinationPath "C:\Tools\$FileName" -CreateFullPath:$true -FileSource Host
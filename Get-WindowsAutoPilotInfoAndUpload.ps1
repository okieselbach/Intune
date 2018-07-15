<#
Version: 1.0
Author:  Oliver Kieselbach
Script:  Get-WindowsAutoPilotInfoAndUpload.ps1

Description:
Get the AutoPilot information and copy it to an Azure Blob Storage. Use existing AzCopy.exe and 
Get-WindowsAutoPilotInfo.ps1 files or download them from an Azure Blob Storage named 'resources'.
If used with an MDT offline media the hash can be written to the offline media as well.

Release notes:
Version 1.0: Original published version.

The script is provided "AS IS" with no warranties.
#>

# Supporting archive files needs to be in Blob Storage
#
# Get-WindowsAutoPilotInfo.ps1
# AzCopy.zip

Function Start-Command {
    Param([Parameter (Mandatory=$true)]
          [string]$Command, 
          [Parameter (Mandatory=$true)]
          [string]$Arguments)

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $Command
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    [pscustomobject]@{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode  
    }
}

# base parameters
$containerUrl = "https://ZZZZ.blob.core.windows.net"
$blobStorageResources = "resources"
$blobStorageHashes = "hashes"
$sasToken = "XXXX"

$scriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$fileName = "$env:computername.csv"
$outputPath = Join-Path $env:windir "temp\AutoPilotScript"
$outputFile = Join-Path $outputPath $fileName

if (-not (Test-Path $outputPath)) {
    New-Item -Path $outputPath -ItemType Directory | Out-Null
}

# define to search in current script directory for needed files
$autoPilotScript = Join-Path $scriptPath "Get-WindowsAutoPilotInfo.ps1"
$azCopyExe = Join-Path $scriptPath "AzCopy.exe"

if (-not (Test-Path $autoPilotScript)) {
    # download Get-WindowsAutoPilotInfo.ps1 from BlobStorage
    Start-BitsTransfer -Source "$containerUrl/$blobStorageResources/Get-WindowsAutoPilotInfo.ps1" -Destination $outputPath

    # re-define variable to output path as we downloaded the files just in time
    $autoPilotScript = Join-Path $outputPath "Get-WindowsAutoPilotInfo.ps1"
}

# Gather the AutoPilot Hash information
Start-Command -Command "$psHome\powershell.exe" -Arguments "-ex bypass -file `"$autoPilotScript`" -ComputerName $env:computername -OutputFile `"$outputFile`"" | Out-Null

if (-not (Test-Path $azCopyExe)) {
    # download AzCopy from BlobStorage
    Start-BitsTransfer -Source "$containerUrl/$blobStorageResources/AzCopy.zip" -Destination $outputPath
    
    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::ExtractToDirectory($(Join-Path $outputPath "AzCopy.zip"), $(Join-Path $outputPath "AzCopy"))

    # re-define variable to output path as we downloaded the files just in time
    $azCopyExe = Join-Path $outputPath "AzCopy\AzCopy.exe"
}

# Copy the hash information to the Blob Storage
$url = "$containerUrl/$blobStorageHashes"
$result = Start-Command -Command "`"$azCopyExe`"" -Arguments "/Source:`"$outputPath`" /Dest:$url /Pattern:$fileName /Y /Z:`"$(Join-Path $outputPath "AzCopy")`" /DestSAS:`"$sasToken`""


# We try to copy the hash information to the scriptpath as the device might be installed from MDT offline media
# ScriptPath would be pointing to the removable media for the offline install. In failure case we could use the gathered
# information from the offline media to try the upload again.
# this can easily be enabled/disabled by defining $offlineMediaCopy = $true/$false
$offlineMediaCopy = $false
if ($offlineMediaCopy) {
    try {
        if ($result.stdout.Contains("Transfer successfully:   1")) {
            $path = $(Join-Path $scriptPath "autopilot-script-success")
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory | Out-Null
            }
            Copy-Item -Path $outputFile -Destination $path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        else {
            $path = $(Join-Path $scriptPath "autopilot-script-failed")
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory | Out-Null
            }
            Copy-Item -Path $outputFile -Destination $path -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch [system.exception]
    {}
}


# Cleanup
Remove-Item -Path $(Join-Path $outputPath "AzCopy.zip") -Force | Out-Null
Remove-Item -Path $(Join-Path $outputPath "AzCopy") -Recurse -Force | Out-Null

# we keep a copy of the hash in the filesystem (temp) just in case something went wrong, you can uncomment and delete the hash information also
#Remove-Item -Path $(Join-Path $scriptPath "Get-WindowsAutoPilotInfo.ps1") -Force | Out-Null
#Remove-Item -Path $outputFile -Force | Out-Null

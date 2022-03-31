#Requires -RunAsAdministrator

<#
Version: 2.0
Author:  Oliver Kieselbach
Script:  GetDecryptInfoFromSideCarLogFiles.ps1
Date:    3/29/2022

Description:
run as Admin on a device where you are AADJ and Intune enrolled to successfully decrypt 
the log message containing decryption info for Intune Win32 apps (.intunewin)

Release notes:
Version 1.0: Original published version.
             initial blog here: https://oliverkieselbach.com/2019/01/03/how-to-decode-intune-win32-app-packages/
Version 2.0: Added ability to turn on 'Verbose' logging for IME and changed the search string to identify the necessary log entry.
             read more about the new version here: https://oliverkieselbach.com/2022/03/30/ime-debugging-and-intune-win32-app-decoding-part-2/

The script is provided "AS IS" with no warranties.
#>

Param(
    [Parameter(Mandatory = $false)] [switch] $EnableVerboseLogging,
    [Parameter(Mandatory = $false)] [switch] $DisableVerboseLogging,
    [Parameter(Mandatory = $false)] [switch] $RunDownloadAndExtract,
    [Parameter(Mandatory = $false)] [string] $TargetDirectory
)

function PrepareSideCarAgentLogLevel($level = 'Verbose')
{
    try {
        $agentConfigPath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe.config"
        $agentConfig = [xml](Get-Content -Path $agentConfigPath -Encoding UTF8)
        
        if ($agentConfig.configuration.'system.diagnostics'.sources.source.switchValue -ne $level)
        {
            $agentConfig.configuration.'system.diagnostics'.sources.source.SetAttribute('switchValue', $level)
            $agentConfig.Save($agentConfigPath)

            # restarting IME to activate new logging level
            Restart-Service -Name IntuneManagementExtension

            Write-Host "SUCCESS: IME log level changed to [$level]"
        }
        else {
            Write-Host "IME log level already set to [$level]"
        }
    }
    catch {
        Write-Host "ERROR: IME log level could not be changed to [$level]"
    }
}

function Decrypt($base64string)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null

    $content = [Convert]::FromBase64String($base64string)
    $envelopedCms = New-Object Security.Cryptography.Pkcs.EnvelopedCms
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $envelopedCms.Decode($content)
    $envelopedCms.Decrypt($certCollection)

    $utf8content = [text.encoding]::UTF8.getstring($envelopedCms.ContentInfo.Content)

    return $utf8content
}

function ExtractIntuneAppDetailsFromLogFile()
{
    $agentLogPath = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
    $stringToSearch = "<![LOG[Response from Intune = {".ToLower()

    Get-Content $agentLogPath | ForEach-Object {
        if ($nextLine) {
            if ($_.ToString().ToLower().Contains("decryptinfo") -And -Not  $_.ToString().ToLower().Contains("outbound data:"))
            {
                try {
                    $reply = "{$($_.ToString().TrimStart())}" | ConvertFrom-Json
                
                    $responsePayload = ($reply.ResponsePayload | ConvertFrom-Json)
                    $contentInfo = ($responsePayload.ContentInfo | ConvertFrom-Json)
                    $decryptInfo = Decrypt(([xml]$responsePayload.DecryptInfo).EncryptedMessage.EncryptedContent) | ConvertFrom-Json

                    "URL: $($contentInfo.UploadLocation)"
                    "Key: $($decryptInfo.EncryptionKey)"
                    "IV:  $($decryptInfo.IV)"

                    if ($RunDownloadAndExtract) {
                        $targetPath = Join-Path $TargetDirectory "$($responsePayload.ApplicationId).intunewin"
                        .\IntuneWinAppUtilDecoder.exe `"$($contentInfo.UploadLocation)`" /key:$($decryptInfo.EncryptionKey) /iv:$($decryptInfo.IV) /filePath:`"$targetPath`"
                    }

                    $nextLine = $false
                }
                catch {
                    Write-Host "Probably no 'Verbose' logging turned on. Run script with '-EnableVerboseLogging' parameter to enable verbose logging for IME"
                }
            }
        }
        if ($_.ToString().ToLower().StartsWith($stringToSearch) -eq $true) {
            $nextLine = $true
        }
    }
}

if ($EnableVerboseLogging) {
    PrepareSideCarAgentLogLevel('Verbose')
}
elseif ($DisableVerboseLogging) {
    PrepareSideCarAgentLogLevel('Information')
}
else {
    ExtractIntuneAppDetailsFromLogFile
}
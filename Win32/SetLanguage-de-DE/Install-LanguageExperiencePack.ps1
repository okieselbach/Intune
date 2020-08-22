<#
Author:  Oliver Kieselbach (oliverkieselbach.com)
Script:  Install-LanguageExperiencePack.ps1

Description:
Main goal: usage of only online sources to install and configure all necessary language files to prevent maintaining 
the package with newer language cab files for future Windows 10 versions.

The online install of LXP is based on the following two articles:
https://docs.microsoft.com/en-us/windows/client-management/mdm/using-powershell-scripting-with-the-wmi-bridge-provider
https://docs.microsoft.com/en-us/windows/client-management/mdm/enterprise-app-management

The script must run in SYSTEM context because of MDM bridge WMI Provider!

Release notes:
Version 1.0: 2020-04-22 - Original published version.

The script is provided "AS IS" with no warranties.
#>

# the language we want as new default
$language = "de-DE"

Start-Transcript -Path "$env:TEMP\LXP-SystemContext-Installer-$language.log" | Out-Null

# found in MS online Store:
# https://www.microsoft.com/de-de/p/english-united-states-local-experience-pack/9pdscc711rvf
#$applicationId = "9pdscc711rvf" # english

# https://www.microsoft.com/de-de/p/deutsch-local-experience-pack/9p6ct0slw589
$applicationId = "9p6ct0slw589" # german

# https://docs.microsoft.com/en-us/configmgr/protect/deploy-use/find-a-pfn-for-per-app-vpn

# Find a PFN if the app is not installed on a computer
# ====================================================
# 1. Go to https://www.microsoft.com/store/apps
# 2. Enter the name of the app in the search bar. In our example, search for OneNote.
# 3. Click the link to the app. Note that the URL that you access has a series of letters at the end. In our example, 
# the URL looks like this: https://www.microsoft.com/store/apps/onenote/9wzdncrfhvjl
# 4. In a different tab, paste the following URL, https://bspmts.mp.microsoft.com/v1/public/catalog/Retail/Products/<app id>/applockerdata, 
# replacing <app id> with the app id you obtained from https://www.microsoft.com/store/apps - that series of letters 
# at the end of the URL in step 3. In our example, example of OneNote, you'd paste: 
# https://bspmts.mp.microsoft.com/v1/public/catalog/Retail/Products/9wzdncrfhvjl/applockerdata.

# found with special API here:
# https://bspmts.mp.microsoft.com/v1/public/catalog/Retail/Products/9pdscc711rvf/applockerdata
#$packageFamilyName = 'Microsoft.LanguageExperiencePacken-US_8wekyb3d8bbwe' # english

# https://bspmts.mp.microsoft.com/v1/public/catalog/Retail/Products/9p6ct0slw589/applockerdata
#$packageFamilyName = 'Microsoft.LanguageExperiencePackde-DE_8wekyb3d8bbwe' # german

# Andrew Cooper simplified it even more to automatically parse the packageFamilyName, thanks for this small tweak even less to configure then
$webpage = Invoke-WebRequest -UseBasicParsing -Uri "https://bspmts.mp.microsoft.com/v1/public/catalog/Retail/Products/$applicationId/applockerdata"
$packageFamilyName = ($webpage | ConvertFrom-JSON).packageFamilyName

# found in Business Store:
# https://businessstore.microsoft.com/en-us/manage/inventory/apps/9P6CT0SLW589/0016/00000000000000000000000000000000;tab=users
$skuId = 0016

# found here:
# https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations?redirectedfrom=MSDN
#$geoId = 244 # United States
$geoId = 94  # Germany

# found here:
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
#$inputLanguageID = "0409:00000409" # en-US
$inputLanguageID = "0407:00000407" # de-DE

# custom folder for temp scripts
"...creating custom temp script folder"
$scriptFolderPath = "$env:SystemDrive\ProgramData\CustomTempScripts"
New-Item -ItemType Directory -Force -Path $scriptFolderPath
"`n"

$languageXmlPath = $(Join-Path -Path $scriptFolderPath -ChildPath "MUI.xml")
# language xml definition for intl.cpl call to switch the language 'welcome screen' and 'new user' defaults
$languageXml = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">

    <!-- user list -->
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
    </gs:UserList>

    <!-- GeoID -->
    <gs:LocationPreferences>
        <gs:GeoID Value="$geoId"/>
    </gs:LocationPreferences>

    <!-- UI Language Preferences -->
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="$language"/>
    </gs:MUILanguagePreferences>

    <!-- system locale -->
    <gs:SystemLocale Name="$language"/>

    <!-- input preferences -->
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="$inputLanguageID" Default="true"/>
    </gs:InputPreferences>

    <!-- user locale -->
    <gs:UserLocale>
        <gs:Locale Name="$language" SetAsCurrent="true" ResetAllSettings="false"/>
    </gs:UserLocale>

</gs:GlobalizationServices>
"@

$userConfigScriptPath = $(Join-Path -Path $scriptFolderPath -ChildPath "UserConfig.ps1")
# we could encode the complete script to prevent the escaping of $, but I found it easier to maintain
# to not encode. I do not have to decode/encode all the time for modifications.
$userConfigScript = @"
`$language = "$language"

Start-Transcript -Path "`$env:TEMP\LXP-UserSession-Config-`$language.log" | Out-Null

`$geoId = $geoId

"explicitly register the LXP in current user session (Add-AppxPackage -Register ...)"
`$appxLxpPath = (Get-AppxPackage | Where-Object Name -Like *LanguageExperiencePack`$language).InstallLocation
Add-AppxPackage -Register -Path "`$appxLxpPath\AppxManifest.xml" -DisableDevelopmentMode

"Set-WinUILanguageOverride = `$language"
Set-WinUILanguageOverride -Language `$language

"Set-WinUserLanguageList = `$language"
Set-WinUserLanguageList `$language -Force

"Set-WinSystemLocale = `$language"
Set-WinSystemLocale -SystemLocale `$language

"Set-Culture = `$language"
Set-Culture -CultureInfo `$language

"Set-WinHomeLocation = `$geoId"
Set-WinHomeLocation -GeoId `$geoId

Stop-Transcript -Verbose
"@

$userConfigScriptHiddenStarterPath = $(Join-Path -Path $scriptFolderPath -ChildPath "UserConfigHiddenStarter.vbs")
$userConfigScriptHiddenStarter = @"
sCmd = "powershell.exe -ex bypass -file $userConfigScriptPath"
Set oShell = CreateObject("WScript.Shell")
oShell.Run sCmd,0,true
"@

# There is a known issue: It is possible for the language pack cleanup task to remove a language pack before the language pack can be used.
# It can be prevented by not allowing to cleanup the language packs.
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/language-packs-known-issue
# IME app install runs by default in 32-bit so we write explicitly to 64-bit registry
"...set reg key: BlockCleanupOfUnusedPreinstalledLangPacks = 1"
& REG add "HKLM\Software\Policies\Microsoft\Control Panel\International" /v BlockCleanupOfUnusedPreinstalledLangPacks /t REG_DWORD /d 1 /f /reg:64
"`n"

# We trigger via MDM method (MDM/WMI Bridge) an install of the LXP via the Store... 
# Imagine to navigate to the store and click the LXP to install, but this time fully programmatically :-). 
# This way we do not have to maintain language cab files in our solution here! And the store install trigger 
# does always download the latest correct version, even when used with newer Windows versions.

# Here are the requirements for this scenario:

# - The app is assigned to a user Azure Active Directory (AAD) identity in the Store for Business. 
#   You can do this directly in the Store for Business or through a management server.
# - The device requires connectivity to the Microsoft Store.
# - Microsoft Store services must be enabled on the device. Note that the UI for the Microsoft Store can be disabled by the enterprise admin.
# - The user must be signed in with their AAD identity.
$namespaceName = "root\cimv2\mdm\dmmap"
$session = New-CimSession

# constructing the MDM instance and correct parameter for the 'StoreInstallMethod' function call
$omaUri = "./Vendor/MSFT/EnterpriseModernAppManagement/AppInstallation"
$newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance "MDM_EnterpriseModernAppManagement_AppInstallation01_01", $namespaceName
$property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", $omaUri, "string", "Key")
$newInstance.CimInstanceProperties.Add($property)
$property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", $packageFamilyName, "String", "Key")
$newInstance.CimInstanceProperties.Add($property)

$flags = 0
$paramValue = [Security.SecurityElement]::Escape($('<Application id="{0}" flags="{1}" skuid="{2}"/>' -f $applicationId, $flags, $skuId))
$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", $paramValue, "String", "In")
$params.Add($param)

try {
    try {
        # we create the MDM instance and trigger the StoreInstallMethod to finally download the LXP
        $instance = $session.CreateInstance($namespaceName, $newInstance)
        $result = $session.InvokeMethod($namespaceName, $instance, "StoreInstallMethod", $params)
    }
    catch [Exception] {
        write-host $_ | out-string
        $exitcode = 1
    }

    if ($result.ReturnValue.Value -eq 0) {
        "...Language Experience Pack install process triggered via MDM/StoreInstall method"
        "...busy wait until language pack found, max 15 min."

        $counter=0
        do {
            Start-Sleep 10
            $counter++

            # check for installed Language Experience Pack (LXP)
            $packageName = "Microsoft.LanguageExperiencePack$language"
            $status = $(Get-AppxPackage -AllUsers -Name $packageName).Status
        
        } while ($status -ne "Ok" -and $counter -ne 90) # 90x10s sleep => 900s => 15 min. max wait time!

        # print some LXP package details for the log
        Get-AppxPackage -AllUsers -Name $packageName

        if ($status -eq "Ok") {
            "...found Microsoft.LanguageExperiencePack$language with Status=Ok"

            # to check for availability with "DISM.exe /Online /Get-Capabilities"

            # we use dism /online /add-cpability switch to trigger an online install and dism will reach out to 
            # Windows Update to get the latest correct source files
            "...trigger install for language FOD packages"
            "`tLanguage.Basic~~~$language~0.0.1.0"
            & DISM.exe /Online /Add-Capability /CapabilityName:Language.Basic~~~$language~0.0.1.0
            "`n"
            "`tLanguage.Handwriting~~~$language~0.0.1.0"
            & DISM.exe /Online /Add-Capability /CapabilityName:Language.Handwriting~~~$language~0.0.1.0
            "`n"
            "`tLanguage.OCR~~~$language~0.0.1.0"
            & DISM.exe /Online /Add-Capability /CapabilityName:Language.OCR~~~$language~0.0.1.0
            "`n"
            "`tLanguage.Speech~~~$language~0.0.1.0"
            & DISM.exe /Online /Add-Capability /CapabilityName:Language.Speech~~~$language~0.0.1.0
            "`n"
            "`tLanguage.TextToSpeech~~~$language~0.0.1.0"
            & DISM.exe /Online /Add-Capability /CapabilityName:Language.TextToSpeech~~~$language~0.0.1.0
            "`n"

            # we have to switch the language for the current user session. The powershell cmdlets must be run in the current logged on user context.
            # creating a temp scheduled task to run on-demand in the current user context does the trick here.
            "...trigger language change for current user session via ScheduledTask = LXP-UserSession-Config-$language"
            Out-File -FilePath $userConfigScriptPath -InputObject $userConfigScript -Encoding ascii
            Out-File -FilePath $userConfigScriptHiddenStarterPath -InputObject $userConfigScriptHiddenStarter -Encoding ascii

            # REMARK: usag of wscript as hidden starter may be blocked because of security restrictions like AppLocker, ASR, etc...
            #         switch to PowerShell if this represents a problem in your environment.
            $taskName = "LXP-UserSession-Config-$language"
            $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "$userConfigScriptHiddenStarterPath"
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance –ClassName Win32_ComputerSystem | Select-Object -expand UserName)
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
            Register-ScheduledTask $taskName -InputObject $task
            Start-ScheduledTask -TaskName $taskName

            Start-Sleep -Seconds 30

            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

            # trigger 'LanguageComponentsInstaller\ReconcileLanguageResources' otherwise 'Windows Settings' need a long time to change finally
            "...trigger ScheduledTask = LanguageComponentsInstaller\ReconcileLanguageResources"
            Start-ScheduledTask -TaskName "\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources"

            Start-Sleep 10

            # change 'welcome screen' and 'new user' language defaults
            "...trigger language change for welcome screen and new user defaults"
            Out-File -FilePath $languageXmlPath -InputObject $languageXml -Encoding ascii

            # check eventlog 'Microsoft-Windows-Internationl/Operational' for troubleshooting
            & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$languageXmlPath`""

            # trigger store updates, there might be new app versions due to the language change
            "...trigger MS Store updates for app updates"
            Get-CimInstance -Namespace $namespaceName -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName "UpdateScanMethod"

            $exitcode = 0
        }
    }
    else {
        $exitcode = 1
    }

    "...cleanup and finish"
    $session.DeleteInstance($namespaceName, $instance) | Out-Null
    Remove-CimSession -CimSession $session
    Remove-Item -Path $scriptFolderPath -Force -Recurse
}
catch [Exception] {
    $session.DeleteInstance($namespaceName, $instance) | Out-Null
    $exitcode = 1
}

if ($exitcode -eq 0) {
    $installed = 1
}
else {
    $installed = 0
}
# IME app install runs by default in 32-bit so we write explicitly to 64-bit registry
& REG add "HKLM\Software\MyIntuneApps" /v "SetLanguage-$language" /t REG_DWORD /d $installed /f /reg:64 | Out-Null

Stop-Transcript -Verbose

exit $exitcode
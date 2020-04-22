<#
Author:  Oliver Kieselbach (oliverkieselbach.com)
Script:  Install-LanguageExperiencePack-de-DE.ps1

Description:
run in SYSTEM context, usage of MDM Bridge WMI Provider to install german language experience pack

Release notes:
Version 1.0: 2020-04-21 - Original published version.

The script is provided "AS IS" with no warranties.
#>

$namespaceName = "root\cimv2\mdm\dmmap"
$session = New-CimSession

$packageFamilyName = 'Microsoft.LanguageExperiencePackde-DE_8wekyb3d8bbwe'
$applicationId = "9p6ct0slw589"
$skuId = 0016

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
    # we create the MDM instance and trigger the StoreInstallMethod
    $instance = $session.CreateInstance($namespaceName, $newInstance)
    $result = $session.InvokeMethod($namespaceName, $instance, "StoreInstallMethod", $params)
}
catch [Exception] {
    write-host $_ | out-string
}

#$session.DeleteInstance($namespaceName, $instance) | Out-Null
Remove-CimSession -CimSession $session
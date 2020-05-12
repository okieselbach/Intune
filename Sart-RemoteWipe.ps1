# https://docs.microsoft.com/en-us/windows/client-management/mdm/using-powershell-scripting-with-the-wmi-bridge-provider
# run in system context

$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_RemoteWipe" 
$methodName = "doWipeMethod"
$session = New-CimSession
$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
$params.Add($param) 
write-host "Triggering RemoteWipe!"
try { 
    $instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'" 
    $session.InvokeMethod($namespaceName, $instance, $methodName, $params) 
}
catch [Exception] { 
    write-host $_ | out-string 
}
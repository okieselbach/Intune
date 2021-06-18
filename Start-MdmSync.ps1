# Author: Oliver Kieselbach (oliverkieselbach.com)
# The script is provided "AS IS" with no warranties.

[Windows.Management.MdmSessionManager,Windows.Management,ContentType=WindowsRuntime]
$session = [Windows.Management.MdmSessionManager]::TryCreateSession()
$session.StartAsync()
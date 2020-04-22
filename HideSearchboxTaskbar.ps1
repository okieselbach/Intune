$registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
$registryKey = "SearchboxTaskbarMode"
$registryValue = 0
    
Set-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -Force -ErrorAction Stop
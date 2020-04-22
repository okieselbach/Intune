$language = "de-DE"

$app = "SetLanguage-$language"
$property = Get-ItemProperty -Path HKLM:\Software\MyIntuneApps -Name $app -ErrorAction SilentlyContinue
if ($property.$app -eq 1) {
    Write-Output "$app detected."
}
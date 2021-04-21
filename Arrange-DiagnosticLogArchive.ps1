# https://techcommunity.microsoft.com/t5/intune-customer-success/intune-public-preview-windows-10-device-diagnostics/ba-p/2179712?utm_source=dlvr.it&utm_medium=twitter

param($DiagnosticArchiveZipPath) 
 
#region Formatting Choices 
$flatFileNameTemplate = '({0:D2}) {1} {2}' 
$maxLengthForInputTextPassedToOutput = 80 
#endregion 
 
#region Create Output Folders and Expand Zip 
$diagnosticArchiveTempUnzippedPath = $DiagnosticArchiveZipPath + "_expanded" 
if(-not (Test-Path $diagnosticArchiveTempUnzippedPath)){mkdir $diagnosticArchiveTempUnzippedPath} 
$reformattedArchivePath = $DiagnosticArchiveZipPath + "_formatted" 
if(-not (Test-Path $reformattedArchivePath)){mkdir $reformattedArchivePath} 
Expand-Archive -Path $DiagnosticArchiveZipPath -DestinationPath $diagnosticArchiveTempUnzippedPath 
#endregion 
 
#region Discover and Move/rename Files 
$resultElements = ([xml](Get-Content -Path (Join-Path -Path $diagnosticArchiveTempUnzippedPath -ChildPath "results.xml"))).Collection.ChildNodes | Foreach-Object{ $_ } 
$n = 1 
 
# only process supported directives 
$supportedDirectives = @('Command', 'Events', 'FoldersFiles', 'RegistryKey') 
foreach( $element in $resultElements) { 
  # only process supported directives, skip unsupported ones 
  if(!$supportedDirectives.Contains($element.Name)) { continue } 
 
  $directiveNumber = $n 
  $n++ 
  $directiveType = $element.Name 
  $directiveStatus = [int]$element.Attributes.ItemOf('HRESULT').psbase.Value 
  $directiveUserInputRaw = $element.InnerText 
 
  # trim the path to only include the actual command - not the full path 
  if ($element.Name -eq 'Command') { 
    $lastIndexOfSlash = $directiveUserInputRaw.LastIndexOf('\'); 
    $directiveUserInputRaw = $directiveUserInputRaw.substring($lastIndexOfSlash+1); 
  } 
 
  $directiveUserInputFileNameCompatible = $directiveUserInputRaw -replace '[\\|/\[\]<>\:"\?\*%\.\s]','_' 
  $directiveUserInputTrimmed = $directiveUserInputFileNameCompatible.substring(0, [System.Math]::Min($maxLengthForInputTextPassedToOutput, $directiveUserInputFileNameCompatible.Length)) 
  $directiveSummaryString = $flatFileNameTemplate -f $directiveNumber,$directiveType,$directiveUserInputTrimmed 
  $directiveOutputFolder = Join-Path -Path $diagnosticArchiveTempUnzippedPath -ChildPath $directiveNumber 
  $directiveOutputFiles = Get-ChildItem -Path $directiveOutputFolder -File 
  foreach( $file in $directiveOutputFiles) { 
    $leafSummaryString = $directiveSummaryString,$file.Name -join ' ' 
    Copy-Item $file.FullName -Destination (Join-Path -Path $reformattedArchivePath -ChildPath $leafSummaryString) 
  } 
} 
#endregion  
Remove-Item -Path $diagnosticArchiveTempUnzippedPath -Force -Recurse
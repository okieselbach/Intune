function Write-Log
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string]$Message,

        # using CCMLog component as it is always visible and additionally append line number for easy troubleshooting
        [Parameter(Mandatory = $false)]
        [string]$Component = "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Information", "Warning", "Error")]
        [string]$LogLevel = "Information"
    )

    begin {
        if ([string]::IsNullOrEmpty($global:scriptLogPath)) {
            # using a global variable to easily overwrite it in main script
            $global:scriptLogPath = $env:TEMP
        }

        # determine log name dynamically
        $path = Join-Path -Path $global:scriptLogPath -ChildPath "$(($MyInvocation.ScriptName | Split-Path -Leaf).Split('.')[0]).log"
    }
    process {
        switch ($LogLevel) {
            "Verbose" { $logLevelInteger = 0 }
            "Information" { $logLevelInteger = 1 }
            "Warning" { $logLevelInteger = 2 }
            "Error" { $logLevelInteger = 3 }
        }
        
        $time = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
        $line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
        $format = $Message, $time, (Get-Date -Format MM-dd-yyyy), $Component, $logLevelInteger
        $line = $line -f $format

        Add-Content -Value $line -Path $path -Force
    }
}

"line1", "line2", "line3", "" | Write-Log

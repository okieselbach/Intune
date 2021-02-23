<#
.SYNOPSIS
    Download a screen ratio optimized wallpaper and apply it to the desktop.

    MIT License

    Copyright (c) 2021 Oliver Kieselbach

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

.DESCRIPTION
    The script determines the screen ratio of the primary monitor and downloads a wallpaper for this ratio 
    from a blob storage address. In certain cases the ratio has a fallback if a wallpaper with the detected 
    ratio is not found.

    The name pattern can be modified, by default it is e.g. wallpaper-16x9.jpg

    As a minimum you should provide 16x9, 3x2 and probably 16x10 (as it becomes a standard) on the blob 
    storage.

    Suggested minimum set of wallpapers on the blob storage:
    - wallpaper-16x9.jpg
    - wallpaper-3x2.jpg
    - wallpaper-16x10.jpg
    ...add additional ones like wallpaper-4x3.jpg if needed

    ! The script must run in user context.

    1. Script detects the missing pre-defined wallpaper (filesystem check), downloads the image and applies 
       it. If pre-defined wallpaper gets deleted and script re-runs, the wallpaper will be applied again.
    2. Script detects on re-run the current wallpaper (registry)
        a. if a user-defiend wallpaper ist set, nothing happens
        b. if the pre-defined wallpaper is still set, it will re-download and apply the new one again,
           this way the wallpaper can be updated only for devices running still the pre-defined wallpaper.
.NOTES
    Author:  Oliver Kieselbach
    Website: oliverkieselbach.com

    Releasenotes
    Version 1.0: Original published version.
#>

# Inline c# code to refresh the wallpaper. Alternative is to call it via rundll32
# rundll32.exe user32.dll, UpdatePerUserSystemParameters, 1, True
Add-Type @"
    using System.Runtime.InteropServices;

    public class Wallpaper {
        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

        public static void Refresh(string path) {
            SystemParametersInfo(20, 0, path, 0x01|0x02); 
        }
    }
"@

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
        # $path = Join-Path -Path $global:scriptLogPath -ChildPath "$(($MyInvocation.ScriptName | Split-Path -Leaf).Split('.')[0]).log"

        # When running from Intune Management Extension (IME) the script has a <guid>_<guid>.ps1 name, for this case we set it manually here
        # we are still logging the original script name for the component column in CCMLog
        $path = Join-Path -Path $global:scriptLogPath -ChildPath "Set-Wallpaper.log"
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

# Ratio calculation is based on work from here: 
# http://michaelflanakin.com/Blog/tabid/142/articleType/ArticleView/articleId/1115/Default.aspx

# === Ratio calculation helper ===
function Get-Divisors($n)
{
    $div = @()

    foreach ($i in 1..($n/3)) {
        $d = $n/$i
        if (($d -eq [System.Math]::Floor($d)) -and -not ($div -contains $i)) {
            $div += $i
            $div += $d
        }
    }

    $div | Sort-Object
}

function Get-CommonDivisors($x, $y)
{
    $xd = Get-Divisors $x
    $yd = Get-Divisors $y
    $div = @()

    foreach ($i in $xd) { 
        if ($yd -contains $i) { 
            $div += $i 
        } 
    }

    $div | Sort-Object
}

function Get-GreatestCommonDivisor($x, $y)
{
    $d = Get-CommonDivisors $x $y
    $d[$d.Length-1]
}

function Get-Ratio($x, $y)
{
    $d = Get-GreatestCommonDivisor $x $y

    New-Object PSObject -Property @{
        X = $x
        Y = $y
        Divisor = $d
        XRatio = $x/$d
        YRatio = $y/$d
        Ratio = "$($x/$d):$($y/$d)"
    };
}
# === Ratio calculation helper ===

function Invoke-WallpaperDownload($imageName)
{
    $url = "$($global:baseUrl.TrimEnd("/"))/$imageName"
    $imagePath = Join-Path -Path $global:wallpaperPath -ChildPath $imageName

    Write-Log -Message "Downloading $url" -LogLevel Information
    Invoke-WebRequest -Uri $url -OutFile $imagePath -TimeoutSec 10 -UseBasicParsing:$true -ErrorAction SilentlyContinue

    if (-not (Test-Path $imagePath)) {
        Write-Log -Message "Missing $imageName image file" -LogLevel Warning
        return $false
    }
    else {
        return $true
    }
}

function Get-Wallpaper
{
    Add-Type -AssemblyName System.Windows.Forms
    #[System.Windows.Forms.Screen]::AllScreens

    $x = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    $y = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height

    $ratio = Get-Ratio $x $y
    Write-Log -Message "Found ratio $($ratio.Ratio) with resolution $($ratio.X)x$($ratio.Y) for primary monitor" -LogLevel Information

    # min. required wallpaper ratios are: 16x9, 3x2
    # but you should add 16x10 as well as it becoming more and more a standard.

    # we map ratio to wallpapers and in case if they are missing we map them to alternatives
    # this will end up in a good looking wallpaper predefined for the user after enrollment.

    switch ($ratio.Ratio) {

        "16:9" { # => probably the most used ratio right now 1920x1080, 3840x2160
            $imageName = "$global:wallpaper-16x9.$global:ext"
            Invoke-WallpaperDownload $imageName | Out-Null
        } 
        { $_ -eq "16:10" -or $_ -eq "8:5" } { # => trending, becoming a standard! 1920x1200, 2560x1600
            $imageName = "$global:wallpaper-16x10.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-16x9.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        } 
        "3:2" { # => not that uncommen ratio right now e.g. Surface lineup 3000x2000, 3240x2160
            $imageName = "$global:wallpaper-3x2.$global:ext"
            Invoke-WallpaperDownload $imageName | Out-Null
        }

        # -- wide screens --

        "32:9" { # ultra wide screens 5120x1440
            $imageName = "$global:wallpaper-32x9.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-16x9.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
             }
        }
        { $_ -eq "21:9" -or $_ -eq "64:27" -or $_ -eq "43:18" -or $_ -eq "12:5" } { # wide screens 2560x1080, 3440x1440
            $imageName = "$global:wallpaper-21x9.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-16x9.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }

        # -- everything below is not very common ---

        "4:3" { # old monitor standard ratio 1440x1080, 1600x1200
            $imageName = "$global:wallpaper-4x3.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-3x2.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }
        "5:4" { # old ratio not very common any more 1280×1024, 2560x2048
            $imageName = "$global:wallpaper-5x4.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-3x2.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }
        "5:3" { # old ratio not very common any more 1280×768, 800x480
            $imageName = "$global:wallpaper-5x4.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-3x2.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }
        "1:1" { # ratio for some professional monitors 2048x2048
            $imageName = "$global:wallpaper-1x1.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-3x2.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }
        "4:1" { # ratio for some advertisement displays
            $imageName = "$global:wallpaper-4x1.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-16x9.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }
        { $_ -eq "256:135" -or $_ -eq "17:9" } { # cinematic 4k displays (not very common) 2048x1080, 4096×2160
            $imageName = "$global:wallpaper-17x9.$global:ext"
            if (-not (Invoke-WallpaperDownload $imageName)) {
                $imageName = "$global:wallpaper-16x9.$global:ext"
                Invoke-WallpaperDownload $imageName | Out-Null
            }
        }

        Default { # fallback to most used standard 16x9 if ratio is unknown
            $imageName = "$global:wallpaper-16x9.$global:ext"
            Invoke-WallpaperDownload $imageName | Out-Null
        }
    }

    return $imageName
}

function Set-Wallpaper
{
    $imageName = Get-Wallpaper
    $path = $(Join-Path -Path $global:wallpaperPath -ChildPath $imageName)

    if (-not (Test-Path $path)) {
        Write-Log -Message "Wallpaper not successful downloaded" -LogLevel Warning
    }
    else {
        Write-Log -Message "Using downloaded $path image file" -LogLevel Information
        Write-Log -Message "Trigger wallpaper refresh" -LogLevel Information
        [Wallpaper]::Refresh($path)
        Write-Log -Message "Wallpaper successful downloaded and refresh triggered" -LogLevel Information
    }
}

#--------------------------
#--- Main script start ----
#--------------------------
Write-Log -Message "-Start script block" -LogLevel Information

# blob storage base URL to get the wallpapers from
$global:baseUrl = "https://XXXX.blob.core.windows.net/resources" 

# Image name pattern based on variables and ratio e.g. wallpaper-16x9.jpg
$global:wallpaper = "wallpaper"
$global:ext = "jpg"

# location where to store the downloaded wallpaper
$global:wallpaperPath = $env:LOCALAPPDATA
Write-Log -Message "Using wallpaper path: $global:wallpaperPath" -LogLevel Information


$searchPath = Join-Path -Path $global:wallpaperPath -ChildPath "$global:wallpaper-*.$global:ext"

if (Test-Path $searchPath) {
    Write-Log -Message "Wallpaper already downloaded here: $global:wallpaperPath" -LogLevel Information
    
    $regkey = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -ErrorAction SilentlyContinue
    if ($null -eq $regkey) {
        Write-Log -Message "Missing wallpaper key in registry, not touching anything" -LogLevel Warning
    }
    else {
        $currentWallpaper = $regkey.WallPaper
        Write-Log -Message "Current wallpaper set in registry: $currentWallpaper" -LogLevel Information
    
        # check if current wallpaper is still set to our wallpaper and not a user defined one. 
        # if a user defined one is set in the meanwhile, we are not going to change it!
        if ($currentWallpaper.StartsWith($(Join-Path -Path $global:wallpaperPath -ChildPath "$global:wallpaper-")) -and
            $currentWallpaper.EndsWith($global:ext)) {
    
            Write-Log -Message "No user-defined wallpaper found for user [$env:USERNAME], triggering re-download and update" -LogLevel Information
    
            # enforce new download, so we can replace it with an updated one
            Remove-Item -Path $searchPath -Force -ErrorAction SilentlyContinue      
            Set-Wallpaper
        }
        else {
            Write-Log -Message "User-defined wallpaper found for user [$env:USERNAME], nothing to do" -LogLevel Information
        }
    }
}
else { # no image downloaded yet, go and get the wallpaper and set it
    Write-Log -Message "Wallpaper not found, trigger Set-Wallpaper procedure" -LogLevel Information
    # download and refresh
    Set-Wallpaper
}

Write-Log -Message "-End script block" -LogLevel Information
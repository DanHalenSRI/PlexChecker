 <#
  .SYNOPSIS
  Author: Dan Barton
  Written On: 03/20/2023 

  .DESCRIPTION
  The PlexChecker script checks the local plex webserver for a return code of 200 to ensure
  it is running.  Upon failure, it will remediate by killing all Plex processes and starting
  Plex Media Server.exe

  .INPUTS
  Trigger Verbose debugging with PlexChecker -Verbose

  .OUTPUTS
  PlexChecker will output logs to a user designated log file.

  .EXAMPLE
  PS> PlexChecker -Verbose
#>

function WriteLog {
    PARAM(
        [string]$logString
    )
    $logFile = "C:\Users\user\Desktop\PlexChecker.log"
    $dateStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logContent = "$dateStamp $logString"
    Write-Verbose "$logString (Logged)"
    Add-content $logFile -value $logContent
}
    
function StartPlex {
    Param(
        [string]$plexInstall,
        [int]$plexStartupWaitTime,
        [switch]$firstRun
    )
    
    if ($null -eq (Get-Process -ProcessName "Plex Media Server" -ErrorAction SilentlyContinue)) {
        if ($firstRun) {
            WriteLog "Plex is not running.  Starting Plex before proceeding to PlexChecker."
        }
        if ($false -eq (Test-Path -Path $plexInstall)) {
            WriteLog "Plex install variable or directory needs attention.  Please check $plexInstall directory."
            WriteLog "Attempting to automatically locate Plex Media Server.exe..."
            $plexLocation = (Get-ChildItem -Path  'C:\Program Files (x86)', 'C:\Program Files' -Recurse -Include "Plex Media Server.exe" -ErrorAction SilentlyContinue).FullName
            if ($null -ne $plexLocation) {
                WriteLog "Plex was found here: $plexLocation.  Update PlexInstall Variable"
                $plexInstall = $plexLocation
            }
            else {
                WriteLog "Plex was not found in Program Files or Program Files (x86).  Please locate install directory and upate the plexInstall variable.  Exiting PlexChecker."
                exit
            }
        }
        Start-Process -FilePath $plexInstall -Verbose
        WriteLog "Waiting $plexStartupWaitTime before proceeding to PlexChecker."
        Start-Sleep -Seconds $plexStartupWaitTime
    } 
    if ($firstRun) {
        WriteLog "Plex is already running!"
    }
}
   
function PlexChecker {

    <#
.PARAMETER localPlexServer
The local webserver address for the plex server.  Yours may be different than the default.
if so update the Parameter to ensure the script does not continuously kill and start Plex.

.PARAMETER plexInstall
The install location for Plex.  Yours may be different than the default.  If so, update 
the parameter.  The script will try to find it automatically, but slows down the process.

.PARAMETER checkInterval
How often you want the script to check your Plex Server.  60 seconds is default, but 
set it to whatever you would like.

.PARAMETER plexStartupWaitTime
How long the script waits after Plex is started for the first time or after a failure
before checking the web server.  If set too quickly, the script will eat it's own tail. 
Slower systems may need more time.  Beefy systems may need less.
#>

    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$localPlexServer = "http://127.0.0.1:32400/web/index.html#!/",
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$plexInstall = "C:\Program Files (x86)\Plex\Plex Media Server\Plex Mediad Server.exe", 
        [Parameter(Mandatory = $false, Position = 2)]
        [int]$checkInterval = 60,
        [Parameter(Mandatory = $false, Position = 3)]
        [int]$plexStartupWaitTime = 120
    )

    WriteLog "Script initialization.  Checking if Plex is already running." -Verbose
    StartPlex -plexInstall $plexInstall -plexStartupWaitTime $plexStartupWaitTime -firstRun -Verbose    
    WriteLog "Starting PlexChecker! This script will check Plex every $checkInterval seconds"
    
    While ($true) {
        Write-Verbose "Resetting plexStatus variable to null"
        $plexStatus = $null
        Write-Verbose "Checking Plex Server!"
        $plexStatus = Invoke-WebRequest -URI $localPlexServer -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
        if ($plexStatus.StatusCode -eq "200") {
            Write-Verbose "Plex is returning Code 200 - OK.  Waiting $checkInterval Seconds"
            Start-Sleep -Seconds $checkInterval 
        }
        else {
            WriteLog "Plex does not appear to be functioning.  Starting Remediation Process." 
            writeLog "Getting and killing all Plex Processes..."
            $plexProcs = Get-Process -ProcessName "Plex*" -ErrorAction SilentlyContinue
            if ($null -ne $plexProcs) {
                WriteLog $plexProcs.ProcessName
                foreach ($proc in $plexProcs) {
                    Write-Verbose "Stopping" $proc.ProcessName
                    Stop-Process -Name $proc.ProcessName -force
                }
                Write-Verbose "Waiting 15 Seconds before attempting to start Plex..."
                Start-Sleep -Seconds 15 -Verbose
            } 
            else {
                WriteLog "No Plex processes currently running, attempting to start Plex..."
            }
            StartPlex -plexInstall $plexInstall -plexStartupWaitTime $plexStartupWaitTime -Verbose
        }
    }
} 
  

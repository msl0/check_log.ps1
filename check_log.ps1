<#
    $Logfile - path to logfile
    $Oldlog  - temp path to file where will be stored part of log file checked by plugin, used to specify diff from $Logfile
    $Query   - case-sensitive search string, when plugin match pattern in log, it will return CRITICAL state

    Example:.\check_log.ps1 C:\Test.log C:\Temp\Test.log ERROR

#>

Param(
    [Parameter(Mandatory=$false)][string]$Logfile,
    [Parameter(Mandatory=$false)][string]$Oldlog,
    [Parameter(Mandatory=$false)][string]$Query
    )

# check if passed all arguments
if ( $PSBoundParameters.Count -ne 3 ) {
    echo "Please pass correct arguments"
    echo "Usage: .\check_log.ps1 <log_file> <old_log_file> <pattern>"
    echo "For more details use 'Get-Content check_log.ps1'"
    exit $STATE_UNKNOWN
    }

# definition of exit codes
$STATE_OK = 0
$STATE_WARNING = 1
$STATE_CRITICAL = 2
$STATE_UNKNOWN = 3


# check if file exist
$FileExists = Test-Path $Logfile
if ( $FileExists -ne $True ) {
    echo "Log check error: Log file $logfile does not exist!"
    exit $STATE_UNKNOWN
    }


# check if old file exist, if not create copy of $Logfile
# if size of $Oldlog is greter than $Logfile remove it - check for log rotation
$FileExists = Test-Path $Oldlog
If ( $FileExists -ne $True ) {
    Copy-Item $Logfile $Oldlog
    echo "Log check data initialized..."
    exit $STATE_OK
    } elseif ( (Get-Item $Oldlog).Length -gt (Get-Item $Logfile).Length ) {
    Remove-Item $Oldlog
    echo "Cleanup"
    exit $STATE_OK
    }


# create tempfile for store diff between $Oldlog and $Logfile
$tempdiff = [System.IO.Path]::GetTempFileName()

# get content of $Logfile and $Oldlog
$LogContent = Get-Content -Path $Logfile
$OldLogContent = Get-Content -Path $Oldlog

# compare $LogContent and $OldLogContent, save diff to $tempdiff
Compare-Object -ReferenceObject $LogContent -DifferenceObject $OldLogContent | Select-Object -Property InputObject > $tempdiff

# override file $Oldlog using conetent of $Logfile
Set-Content -Path $Oldlog -Value $LogContent

# get lines from $tempdiff which contain $Query
$Grep = Get-Content -Path $tempdiff | Select-String -Pattern $Query -CaseSensitive -SimpleMatch

# get count of $Query occurrences
$Count = ($Grep | Measure-Object).Count

# get the latest line from lines which contain $Query
$LastEntry = $Grep | Select-Object -Last 1

# remove $tempdiff
Remove-Item $tempdiff

# if $Query no occure return OK state
# if occure, return CRITICAL, count of line with $Query and latest line which $Query
if ( $Count -eq 0 ) {
    echo "Log check ok - 0 pattern matches found"
    exit $STATE_OK
    }
else {
    echo "($Count) $LastEntry"
    exit $STATE_CRITICAL
    }

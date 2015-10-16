#requires -version 3
<#
 Script that dumps all Stash permissions and filter audit logs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    $app_credential = (Get-Credential -Message "Bitbucket (Stash) Application credentials"),
    [Parameter(Mandatory=$True)]
    $srv_credential = (Get-Credential -Message "Server running Bitbucket (Stash) credentials")
)

$VerbosePreference = "SilentlyContinue"
$DebugPreference = "SilentlyContinue"
# $VerbosePreference = "Continue"
# $DebugPreference = "Continue"
$cleanup = $false

$serverURL = "https://stash.example.com:8443"
$excludeUsers = @("admin")

$bitbucketHost = "stash.example.com"
$bitbucketLogDirectory = "/var/stash/log/audit"

# reference date in previous month
[datetime] $referenceDate = (Get-Date).AddDays(-25)
$reportFolder = Join-Path $env:TEMP -ChildPath "bitbucket-report-$($referenceDate.ToString('MMM-yyyy'))"

$From = 'stash@example.com'
$To = 'admin@example.com'
$CC = $To
$SmtpServer = 'smtp.example.com'


Add-Type -assembly "system.io.compression.filesystem"
$pathToScripts = $PSScriptRoot


# permission
& "$pathToScripts/Bitbucket-Permissions-Report.ps1" $app_credential $referenceDate $reportFolder $serverURL $excludeUsers $cleanup


# audit
$filter = {
    [CmdletBinding()]param([Parameter(ValueFromPipeline=$true)]$obj)
    # build servers
    if ($obj.Source_IP -in '192.0.2.1','192.0.2.2') { return }
    # noise
    if ($obj.Event -eq 'AuthenticationSuccessEvent') { return }
    # checks passed
    return $obj
}
& "$pathToScripts/Bitbucket-Audit-Report.ps1" $bitbucketHost $bitbucketLogDirectory $srv_credential $filter $referenceDate $reportFolder $cleanup


# send out the reports
& "$pathToScripts/Bitbucket-Send-Report.ps1" $From $To $CC $SmtpServer $referenceDate $reportFolder $cleanup


if ($cleanup) {
    Remove-Item $reportFolder -Recurse -Force
}

#EOF#
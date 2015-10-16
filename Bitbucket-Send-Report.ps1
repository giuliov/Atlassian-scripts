<#
 Script sends the content of the report folder to recipients
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string]       $From,
    [Parameter(Mandatory=$True)]
    [string]       $To,
    [Parameter(Mandatory=$False)]
    [string]       $CC = $To,
    [Parameter(Mandatory=$True)]
    [string]       $SmtpServer,
    [Parameter(Mandatory=$False)]
    [datetime]     $referenceDate = (Get-Date).AddDays(-25),
    [Parameter(Mandatory=$False)]
    [string]       $reportFolder = "reports",
    [Parameter(Mandatory=$False)]
    [bool]         $cleanup = $False
) 



Write-Host "Sending Report"

# send out the reports
$zipToAttach = Join-Path -Path $env:TEMP -ChildPath "Bitbucket-Reports-$(Get-Date -Format 'yyyyMMdd-HHmm').zip"
[io.compression.zipfile]::CreateFromDirectory($reportFolder, $zipToAttach)

$head = @"
<style>
BODY{font-family: Arial; font-size: 12pt;}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;background-color:#dddddd}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black}
CODE{display:inline}
</style>
"@
$subject = 'Monthly code access Report'
$body = @"
<p>See attached files for $($referenceDate.ToString('MMMM yyyy')) Report.</p>
"@
Send-MailMessage -From $From -To $To -CC $CC -Subject $subject -SmtpServer $SmtpServer -BodyAsHtml $body -Attachments $zipToAttach


if ($cleanup) {
    Remove-Item $zipToAttach -Force
}


Write-Host "Report sent"
#EOF#
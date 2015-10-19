<#
 Script that parses Bitbucket/Stash audit logs
 Requires https://github.com/darkoperator/Posh-SSH, see there how to install the latest version
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string]       $bitbucketHost,
    [Parameter(Mandatory=$True)]
    [string]       $bitbucketLogDirectory,
    [Parameter(Mandatory=$True)]
    [PSCredential] $credential,
    [Parameter(Mandatory=$False)]
    [ScriptBlock]  $filter = {},
    [Parameter(Mandatory=$False)]
    [datetime]     $referenceDate = (Get-Date).AddDays(-25),
    [Parameter(Mandatory=$False)]
    [string]       $reportFolder = "reports",
    [Parameter(Mandatory=$False)]
    [bool]         $cleanup = $False
)

$pathToScripts = $PSScriptRoot


. "$pathToScripts/Set-FileTime.ps1"
. "$pathToScripts/GZip.ps1"


$fields = "Source_IP","Event","Account","UnixTimestamp","Object","Details","RequestId","not_used"

$unixEpoch = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0, 'Utc'
filter convertUnixTimestamp {
    Add-Member -InputObject $_ -PassThru -Name "Timestamp" -MemberType NoteProperty -Value $script:unixEpoch.AddMilliseconds($_.UnixTimestamp).ToLocalTime()
}



# make sure output dir is there
New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null
$reportFile = Join-Path $reportFolder -ChildPath "bitbucket-audit-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"

# make working place
$workingFolder = Join-Path $env:TEMP -ChildPath "bitbucket-audit-report-$($referenceDate.ToString('MMM-yyyy'))-temp"
New-Item -Path $workingFolder -ItemType Directory -Force | Out-Null

# pull down the audit log files
Write-Host "Downloading Audit logs"
$ssh = New-SSHSession -ComputerName $bitbucketHost -Credential $credential
$ls = (Invoke-SSHCommand -SSHSession $ssh -Command "ls -1 $bitbucketLogDirectory/atlassian-stash-audit-$($referenceDate.ToString("yyyy-MM"))-*.log.gz").Output
$ls | foreach {
    $srcFile = $_
    $filename = Split-Path -Path $srcFile -Leaf
    Get-SCPFile -ComputerName $bitbucketHost -Credential $credential -RemoteFile $srcFile -LocalFile (Join-Path $workingFolder -ChildPath $filename)
}
Remove-SSHSession -SSHSession $ssh

# uncompress
Write-Host "Decompressing Audit logs"
Get-ChildItem $workingFolder -Filter "*.gz" | foreach {
    $audit_file = $_
    Write-Progress -Activity "Expanding downloaded files" -CurrentOperation "Expanding $($audit_file.Name)"
    Expand-GZip -FullName $audit_file.FullName #-NewName [IO.Path]::ChangeExtension($audit_file.FullName,$null)
}


# parse and filter the logs
Write-Host "Parsing and filtering Audit logs"

Get-ChildItem $workingFolder -Filter "*.log" | foreach {
    $audit_file = $_
    Write-Progress -Activity "Processing audit log files" -CurrentOperation "Processing $($audit_file.Name)"
    Get-Content -Path $audit_file.FullName |
        foreach { $_.Replace(" | ","`t") } | 
        ConvertFrom-Csv -Header $fields -Delimiter "`t" |
        foreach { & $filter $_ } |
        convertUnixTimestamp
} | Export-Csv -Path $reportFile -Force -NoTypeInformation 


if ($cleanup) {
    Remove-Item $workingFolder -Recurse -Force
}

Write-Host "Audit processing complete"
#EOF#
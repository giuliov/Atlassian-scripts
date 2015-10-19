<#
 Script that dumps all Bitbucket/Stash permissions using REST API
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [PSCredential] $credential,
    [Parameter(Mandatory=$False)]
    [datetime]     $referenceDate = (Get-Date).AddDays(-25),
    [Parameter(Mandatory=$False)]
    [string]       $reportFolder = "reports",
    [Parameter(Mandatory=$True)]
    [string]       $serverURL,
    [Parameter(Mandatory=$False)]
    [string[]]     $excludeUsers = @("admin"),
    [Parameter(Mandatory=$False)]
    [bool]         $cleanup = $False
) 

### define context ###
$cred_parts = $credential.UserName.Split('\')
if ($cred_parts.Length -gt 1) {
  # DOMAIN\user
$stash_user = $credential.UserName.Split('\')[1]
} else {
  # application user
  $stash_user = $credential.UserName
}
$stash_plain_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password))
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${stash_user}:${stash_plain_password}"))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue;
    "Content-Type" = "application/json"
}

$BASEURL="${serverURL}/rest/api/1.0"
$NOLIMITS="?limit=1000" # do not want paging



function restCall([string]$apiURL)
{
    $result = Invoke-RestMethod -Uri $apiURL -Method Get -Headers $Headers
    if (!$result.isLastPage) {
        Write-Error "Incomplete results for $apiURL"
    }
    return $result.values
}



$all_repositories = @()
$all_user_perms = @() # flat

$all_group_perms = @{} # keyed by group
$all_groups = restCall "${BASEURL}/admin/groups/${NOLIMITS}"
foreach ($group in $all_groups) {
    $script:all_group_perms[ $group.name ] = @()
}#for

$all_userinfo = @{}
$all_users = restCall "${BASEURL}/admin/users${NOLIMITS}"
foreach ($user in $all_users) {
    $script:all_userinfo[ $user.name ] = $user
}#for


function addUsers($userList,[string]$level,[string]$key)
{
    if ($userList -ne $null) {
        $script:all_user_perms += $userList | foreach {
            New-Object -TypeName PSObject -Property @{ userName=$_.user.name; permission=$_.permission; level=$level; objectKey=$key }
        }
    }
}

function addGroups($groupList,[string]$level,[string]$key)
{
    if ($groupList -ne $null) {
        $groupList | foreach {
            $entry = New-Object -TypeName PSObject -Property @{ level=$level; objectKey=$key; permission=$_.permission }
            $script:all_group_perms[ $_.group.name ] += $entry
        }
    }
}


# make sure output dir is there
New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null


Write-Host "Getting projects' permissions"

$projects = restCall "${BASEURL}/projects/${NOLIMITS}"
foreach ($project in $projects) {

    $PROJECTKEY = $project.key
    $_activity = "Processing project '$($project.name)' [$PROJECTKEY]"
    Write-Progress -Activity $_activity

    $project_users = restCall "${BASEURL}/projects/${PROJECTKEY}/permissions/users${NOLIMITS}"
    addUsers $project_users "PROJECT" $PROJECTKEY

    $project_groups = restCall "${BASEURL}/projects/${PROJECTKEY}/permissions/groups${NOLIMITS}"
    addGroups $project_groups "PROJECT" $PROJECTKEY

    $repos = restCall "${BASEURL}/projects/${PROJECTKEY}/repos/${NOLIMITS}"
    foreach ($repo in $repos) {

        $all_repositories += $repo

        <# from https://developer.atlassian.com/static/javadoc/stash/3.11.1/api/reference/com/atlassian/stash/repository/Repository.State.html
            AVAILABLE  	Indicates the repository has been created both in the database and in the associated SCM and may be pulled from or pushed to normally. 
            INITIALISATION_FAILED  	Indicates the associated SCM was not able to create the repository's SCM-specific storage, such as a bare clone on disk in git. 
            INITIALISING  	Indicates the repository has just been created in the database and the associated SCM is currently in the process of creating its storage.
        #>
        if ($repo.state -ne 'AVAILABLE') {
            Write-Host "  Repo $($repo.name) is in $($repo.state) state, skipping."
            continue
        }

	    $REPOSITORYSLUG = $repo.slug
        Write-Progress -Activity $_activity -CurrentOperation "Repo $REPOSITORYSLUG"

        $repo_users = restCall "${BASEURL}/projects/${PROJECTKEY}/repos/${REPOSITORYSLUG}/permissions/users${NOLIMITS}"
        addUsers $repo_users "REPO" $REPOSITORYSLUG
        $repo_groups = restCall "${BASEURL}/projects/${PROJECTKEY}/repos/${REPOSITORYSLUG}/permissions/groups${NOLIMITS}"
        addGroups $repo_groups "REPO" $REPOSITORYSLUG

    }#for

}#for


Write-Host "Post-processing"


$reportFile = Join-Path $reportFolder -ChildPath "bitbucket-repositories.csv"
$all_repositories | foreach{
    New-Object -TypeName PSObject -Property @{ project=$_.project.key; project_long=$_.project.name; repo=$_.name }
} | Export-Csv -Path $reportFile -Force -NoTypeInformation



$_activity = "Processing groups"
Write-Progress -Activity $_activity
# expand groups to individuals
$user_membership_perms = @()
foreach ($GROUPNAME in $all_group_perms.Keys) {
    Write-Progress -Activity $_activity -CurrentOperation "Group '$GROUPNAME'"
    $group_membership = restCall "${BASEURL}/admin/groups/more-members${NOLIMITS}&context=${GROUPNAME}"
    foreach ($user in $group_membership) {
        foreach ($entry in $all_group_perms[$GROUPNAME]) {
            $user_membership_perms += New-Object -TypeName PSObject -Property @{ userName=$user.name; permission=$entry.permission; level=$entry.level; objectKey=$entry.objectKey }
        }
    }
}#for
$all_user_perms += $user_membership_perms


# dump result
$final_table = $all_user_perms | foreach {
    $entry = $_
    $info = $all_userinfo[$entry.userName]
    New-Object -TypeName PSObject -Property @{
        userName=$entry.userName;
        displayName=$info.displayName;
        permission=$entry.permission;
        level=$entry.level;
        object=$entry.objectKey }
}

Write-Progress -Activity $_activity -Completed


$reportFile = Join-Path $reportFolder -ChildPath "bitbucket-user-permissions.csv"
$final_table | where {
    $excludeUsers -notcontains $_.userName
} | sort userName,level,object,permission -Unique |
    Export-Csv -Path $reportFile -Force -NoTypeInformation


$reportFile = Join-Path $reportFolder -ChildPath "bitbucket-object-permissions.csv"
$final_table | where {
    $excludeUsers -notcontains $_.userName
} | sort object,level,permission,userName |
    Export-Csv -Path $reportFile -Force -NoTypeInformation


Write-Host "Permission processing complete"
#EOF#
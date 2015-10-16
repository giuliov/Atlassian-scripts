# Atlassian-scripts
Scripts for automation and reporting on Confluence, Jira, Stash, Bitbucket, Bamboo


## Permission report

`Sample-Bitbucket-Permissions-Report.ps1`

Dump user permissions on CSV files by scanning all repositories. Groups expands to users.
Audit log are filtered and converted to CSV.
All CSV files are packed and attached to a mail sent to managers.

Designed to be run once per month, in the first week of the following month.

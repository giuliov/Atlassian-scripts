# REST API Synopsis

```
# list of projects
${BASEURL}/projects/${NOLIMITS}

# individual users @ project level
${BASEURL}/projects/${PROJECTKEY}/permissions/users${NOLIMITS}
# --> expand

# groups @ project level
${BASEURL}/projects/${PROJECTKEY}/permissions/groups${NOLIMITS}

# list of repos
${BASEURL}/projects/${PROJECTKEY}/repos/${NOLIMITS}

# individual users @ repo level
${BASEURL}/projects/${PROJECTKEY}/repos/${REPOSITORYSLUG}/permissions/users${NOLIMITS}
# --> expand

# groups @ repo level
${BASEURL}/projects/${PROJECTKEY}/repos/${REPOSITORYSLUG}/permissions/groups${NOLIMITS}

# expand groups to individuals
${BASEURL}/admin/groups/more-members${NOLIMITS}&context=${GROUP}

# Stash user to AD user check (expand)
${BASEURL}/admin/users${NOLIMITS}
```

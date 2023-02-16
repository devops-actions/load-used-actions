param (
    [string] $organization,
    [string] $PAT
)

function Get-LocationInfo {
    Write-Host "Where are we? [$pwd]"

    ForEach ($file in Get-ChildItem) {
        Write-Host "- $($file.Name)"
    }
}

function main {

    if ($null -eq $organization -or "" -eq $organization) {
        Write-Host "Using default for organization: [$($env:GITHUB_REPOSITORY_OWNER)]"
        $organization = $($env:GITHUB_REPOSITORY_OWNER)
    }

    if ($null -eq $PAT -or "" -eq $PAT) {
        Write-Error "No value given for input PAT: Use at least [GITHUB_TOKEN]"
        throw
    }

    $actions = (.\load-used-actions.ps1 -orgName $organization -PAT $PAT)

    # wite the file outside of the container so we can pick it up
    Write-Host "Found [$($actions.Count)] actions "
    #Write-Verbose $actions | ConvertTo-Json -Depth 10
    $jsonObject = ($actions | ConvertTo-Json -Depth 10 -Compress)
    Write-Output "Testing GITHUB_OUTPUT: [$($env:GITHUB_OUTPUT)]"
    Write-Output "::set-output name=actions::'$jsonObject'"
    Write-Host "Stored actions in outputs list. Use $${{ steps.<step id>.outputs.actions }} in next action to load the json"
}

try {
    # always run in the correct location, where our scripts are located:
    Set-Location $PSScriptRoot

    # call main script:
    main

    # return the container with the exit code = Ok:    
    exit 0
}
catch {
    # return the container with the last exit code: 
    Write-Error "Error loading the actions:"
    Write-Error $_
    # return the container with an erroneous exit code:
    exit 1
}

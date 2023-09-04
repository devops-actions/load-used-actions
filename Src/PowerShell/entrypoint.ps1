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

function Import-EnvironmentVariables {
    # load the environment variables from the .env file in the root of the repo:
    Get-Content "../../.env" | ForEach-Object {
        $name, $value = $_.split('=')
        # if name already exists, do not overwrite it:
        if ($false -eq (Test-Path env:$name)) {
            if ($null -ne $value -and "" -ne $value) {
                Write-Host "Setting environment variable [$name] to [$value] from the .env file"
                Set-Content env:\$name $value
            }
        }
        else {
            Write-Host "Environment variable [$name] was already set. Value is [$($env:name)]"
        }
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

    # write the file outside of the container so we can pick it up
    Write-Host "Found [$($actions.Count)] actions "
    $jsonObject = ($actions | ConvertTo-Json -Depth 10 -Compress)    
    
    # store the json in a file and write the path to the output variable   
    $fileName = "used-actions.json"
    $filePath = "$($env:GITHUB_WORKSPACE)/$fileName"
    
    Set-Content -Value "$jsonObject" -Path "$filePath"
    Set-Content -Value "actions-file=$fileName" -Path $env:GITHUB_OUTPUT
    Write-Host "Stored actions in the actions output. Use $${{ steps.<step id>.outputs.actions }} in next action to load the json"
    Write-Host "Stored actions file in the actions output. Use $${{ steps.<step id>.outputs.actions-file }} in next action to load the file from the $$GITHUB_WORKSPACE folder"
    
    # write json content to output variable for backward compatibility (this used to be the only way to get the json)
    Add-Content -Value "actions='$jsonObject'" -Path $env:GITHUB_OUTPUT
}

$currentLocation = Get-Location
try {    
    # always run in the correct location, where our scripts are located:
    Set-Location $PSScriptRoot
    Import-EnvironmentVariables

    # call main script:
    main

    Write-Host "Going back to location before the run: [$currentLocation]"
    Set-Location $currentLocation

    # return the container with the exit code = Ok:    
    exit 0
}
catch {
    # return the container with the last exit code: 
    $exitError = $_
    Write-Error "Error loading the actions:"
    Write-Error $exitError

    Write-Host "Going back to location before the run: [$currentLocation]"
    Set-Location $currentLocation

    # return the container with an erroneous exit code:
    exit 1
}

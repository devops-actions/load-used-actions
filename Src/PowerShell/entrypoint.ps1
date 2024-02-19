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
    # checik if the file exists :
    # "../../.env"
    if ($false -eq (Test-Path "../../.env")) {
        Write-Debug "No .env file found in the root of the repo"
        return
    }

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

    echo $pwd
    ls 

    # pull in the methods from load-actions:
    . $PSScriptRoot\load-used-actions.ps1 -orgName $organization -PAT $PAT

    # Get all actions
    $actions = LoadAllActionsFromConfiguration
    if ($null -eq $actions) {
        Write-Error "Could not find any actions"
        throw
    }

    # write the file outside of the container so we can pick it up
    Write-Host "Found [$($actions.Count)] actions"
    $jsonObject = ($actions | ConvertTo-Json -Depth 10 -Compress)    
    
    # store the json in a file and write the path to the output variable   
    $fileName = "used-actions.json"
    $filePath = "$($env:GITHUB_WORKSPACE)/$fileName"

    if ($null -ne $env:GITHUB_WORKSPACE -and "" -ne $env:GITHUB_WORKSPACE) {
        Write-Host "Writing actions to file in workspace: [$($env:GITHUB_WORKSPACE)]"
        Set-Content -Value "$jsonObject" -Path "$filePath"
    }
    else {
        Write-Host "Writing actions to file in current folder: [$($pwd)]"
        $filePath = "./used-actions.json"
        Set-Content -Value "$jsonObject" -Path "$filePath"
    }

    # write the name of the file to the output folder
    Set-Content -Value "actions-file=$fileName" -Path $env:GITHUB_OUTPUT
    Write-Host "Stored actions in the actions output. Use $${{ steps.<step id>.outputs.actions }} in next action to load the json"
    Write-Host "Stored actions file in the actions output. Use $${{ steps.<step id>.outputs.actions-file }} in next action to load the file from the $$GITHUB_WORKSPACE folder"
    
    # write json content to output variable for backward compatibility (this used to be the only way to get the json)
    Add-Content -Value "actions='$jsonObject'" -Path $env:GITHUB_OUTPUT
}

$moduleName = "powershell-yaml"
if (Get-Module -ListAvailable -Name $moduleName) {
    Write-Host "$moduleName Module exists"
} 
else {
    Write-Host "$moduleName Module does not exist"
    Write-Host "Installing module for the yaml parsing"
    Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber
}

try {
    Import-Module $moduleName -Force
}
catch {
    Write-Error "Error importing the $moduleName module"
    throw
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

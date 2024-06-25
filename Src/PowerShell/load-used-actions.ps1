# example calls:
# .\load-used-actions.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT -$marketplaceRepo "rajbos/actions-marketplace"
param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $marketplaceRepo
)

# pull in central calls library
. $PSScriptRoot\github-calls.ps1

function  GetActionsFromWorkflow {
    param (
        [string] $workflow,
        [string] $workflowFileName,
        [string] $repo
    )

    # parse the workflow file and extract the actions used in it
    $parsedYaml =""
    try {
        $parsedYaml = ConvertFrom-Yaml $workflow
    }
    catch {
        Write-Warning "Error parsing the yaml from this workflow file: [$workflowFileName] in repo: [$repo]"
        Write-Warning "Workflow content:"
        Write-Warning $workflow
        Write-Warning ""
        Write-Warning "Error:"
        Write-Warning $_
        return $actions
    }

    # create hashtable
    $actions = @()
    try {
        if ($null -ne $parsedYaml["jobs"] -And "" -ne $parsedYaml["jobs"]) { #else: write info to summary?
            # go through the parsed yaml
            foreach ($job in $parsedYaml["jobs"].GetEnumerator()) {
                Write-Host "  Job found: [$($job.Key)]"
                $steps=$job.Value.Item("steps")
                if ($null -ne $steps) {
                    foreach ($step in $steps) {
                        $uses=$step.Item("uses")
                        if ($null -ne $uses) {
                            Write-Host "   Found action used: [$uses]"
                            $actionLink = $uses.Split("@")[0]
                            $actionRef = $uses.Split("@")[1]

                            $data = [PSCustomObject]@{
                                actionLink = $actionLink
                                actionRef = $actionRef
                                workflowFileName = $workflowFileName
                                repo = $repo
                                type = "action"
                            }

                            $actions += $data
                        }
                    }
                }
                else {
                    # check for reusable workflow
                    $uses = $job.Value.Item("uses")
                    if ($null -ne $uses) {
                        Write-Host "   Found reusable workflow used: [$uses]"
                        $actionLink = $uses.Split("@")[0]
                        $actionRef = $uses.Split("@")[1]

                        $data = [PSCustomObject]@{
                            actionLink = $actionLink
                            actionRef = $actionRef
                            workflowFileName = $workflowFileName
                            repo = $repo
                            type = "reusable workflow"
                        }

                        $actions += $data
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error handling this workflow file [$($workflowFile.name)] in repo [$repo] after parsing it"
        Write-Host "Error: [$_]"
        Write-Host "$parsedYaml"

        if ($null -ne $env:GITHUB_STEP_SUMMARY) {
            $filename = "$env:GITHUB_STEP_SUMMARY"
            $content = Get-Content $filename
            if ($null -eq $content -Or "" -eq $content) {
                Add-Content -path $filename "# Error handling workflow file(s)"
                Add-Content -path $filename "|Repository|Workflow file|Error|"
                Add-Content -path $filename "|---|---|---|"
            }

            Add-Content -path $filename "| $repo | $($workflowFile.name) | $_ |"
        }

    }

    return $actions
}

function GetAllUsedActionsFromRepo {
    param (
        [string] $repo,
        [string] $PAT,
        [string] $userName
    )

    # get all the actions from the repo
    $workflowFiles = GetAllFilesInPath -repository $repo -path ".github/workflows" -PAT $PAT -userName $userName
    if (([string]$workflowFiles).StartsWith("https://docs.github.com/")) {
        Write-Host "Could not get workflow files from [$repo]"
        return;
    }
    
    # create hashtable to store the results in
    $actionsInRepo = @()

    Write-Host "Found [$($workflowFiles.Length)] files in the workflows directory"
    foreach ($workflowFile in $workflowFiles) {
        try {
            if ($null -ne $workflowFile.download_url -and $workflowFile.download_url.Length -gt 0 -and $workflowFile.download_url.Split("?")[0].EndsWith(".yml")) { 
                $workflow = GetRawFile -url $workflowFile.download_url -PAT $PAT -userName $userName
                $actions = GetActionsFromWorkflow -workflow $workflow -workflowFileName $workflowFile.name -repo $repo

                $actionsInRepo += $actions
            }
        }
        catch {
            Write-Warning "Error handling this workflow file [$($workflowFile.name)] in repo [$repo]:"
            Write-Host ($workflowFile | ConvertFrom-Json -Depth 10).Replace($PAT, "****")
            Write-Warning "----------------------------------"
            Write-Host "Error: [$_]"
            Write-Warning "----------------------------------"
            #continue
        }
    }

    return $actionsInRepo
}

function SummarizeActionsUsed {
    param (
        [object] $actions
    )

    $summarized =  @()
    foreach ($action in $actions) {
        $found = $summarized | Where-Object { $_.actionLink -eq $action.actionLink -And $_.actionRef -eq $action.actionRef -And $_.type -eq $action.type }
        if ($null -ne $found) {
            # item already found, add this info to it
            $newInfo =  [PSCustomObject]@{
                repo = $action.repo
                workflowFileName = $action.workflowFileName
            }

            $found.workflows += $newInfo
            $found.count++
        }
        else {
            # new item, create a new object
            $newItem =  [PSCustomObject]@{
                type = $action.type
                actionLink = $action.actionLink
                actionRef = $action.actionRef
                count = 1
                workflows =  @(
                    [PSCustomObject]@{
                        repo = $action.repo
                        workflowFileName = $action.workflowFileName
                    }
                )
            }
            $summarized += $newItem
        }
    }

    return $summarized
}

function LoadAllUsedActionsFromRepos {
    param (
        [object] $repos,
        [string] $userName,
        [string] $PAT,
        [string] $marketplaceRepo
    )

    # create hastable
    $actions = @()
    #$i=0
    foreach ($repo in $repos) {
        if ($null -ne $repo -And $repo.full_name.Length -gt 0) {
            Write-Host "Loading actions from repo: [$($repo.full_name)]"
            $actionsUsed = GetAllUsedActionsFromRepo -repo $repo.full_name -PAT $PAT -userName $userName

            $actions += $actionsUsed

            # comment out code below to stop after a certain number of repos to prevent issues with 
            # rate limiting on the load file count (that is not workin correctly)
            # $i++
            # if ($i -eq 2) {
            #    # break on second result:
            #    Write-Host "Breaking after [$i] repos"
            #    return $actions
            # }
        }
    }

    return $actions
}

function LoadAllActionsFromConfiguration() {

    Write-Host "We're running with these parameters:"
    Write-Host "- PAT.Length: [$($PAT.Length)]"
    Write-Host "- orgName: [$orgName]"

    if ($null -eq $userName -or "" -eq $userName) {
        $userName = $env:GITHUB_ACTOR
    }

    if ($userName -eq "dependabot[bot]") {
        # try to prevent issues with [] in the username
        $userName = "dependabot"
    }

    Write-Host "- userName: [$userName]"
    Write-Host "- marketplaceRepo: [$marketplaceRepo]"

    # get all repos in an org
    $repos = FindAllRepos -orgName $orgName -userName $userName -PAT $PAT

    # get actions from the workflows in the repos
    $actionsFound = LoadAllUsedActionsFromRepos -repos $repos -userName $userName -PAT $PAT -marketplaceRepo $marketplaceRepo

    if ($actionsFound.Count -gt 0) {
                
        $summarizeActions = SummarizeActionsUsed -actions $actionsFound

        Write-Host "Found [$($actionsFound.Count)] actions used in workflows with [$($summarizeActions.Count) unique actions]"

        # write the actions to disk
        $fileName = "summarized-actions.json"
        $jsonObject = ($summarizeActions | ConvertTo-Json -Depth 10)
        New-Item -Path $fileName -Value $jsonObject -Force | Out-Null
        Write-Host "Stored the summarized usage info into this file: [$fileName] in this directory: [$PWD]"

        # upload the data into the marketplaceRepo
        #Write-Host "Found [$($actionsFound.actions.Length)] actions in use!"

        # todo: store the json file
        #UploadActionsDataToGitHub -actions $actionsFound -marketplaceRepo $marketplaceRepo -PAT $PAT -repositoryName $repositoryName -repositoryOwner $repositoryOwner
        
        return $summarizeActions
    }

    return $null
}

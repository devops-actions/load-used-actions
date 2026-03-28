# example calls:
# .\load-used-actions.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT -$marketplaceRepo "rajbos/actions-marketplace"
param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $marketplaceRepo,
    [string] $includeArchivedRepos = "true"
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

                # check for job-level container image (#149)
                $jobContainer = $job.Value.Item("container")
                if ($null -ne $jobContainer) {
                    $containerImage = $null
                    if ($jobContainer -is [string]) {
                        $containerImage = $jobContainer
                    }
                    elseif ($null -ne $jobContainer.Item("image")) {
                        $containerImage = $jobContainer.Item("image")
                    }
                    if ($null -ne $containerImage -and $containerImage.Length -gt 0) {
                        Write-Host "   Found job container image: [$containerImage]"
                        $actions += [PSCustomObject]@{
                            actionLink = $containerImage
                            actionRef = $null
                            actionVersionComment = $null
                            workflowFileName = $workflowFileName
                            repo = $repo
                            type = "container-image"
                        }
                    }
                }

                # check for job-level services / sidecars (#149)
                $services = $job.Value.Item("services")
                if ($null -ne $services) {
                    foreach ($service in $services.GetEnumerator()) {
                        $serviceImage = $null
                        if ($service.Value -is [string]) {
                            $serviceImage = $service.Value
                        }
                        elseif ($null -ne $service.Value.Item("image")) {
                            $serviceImage = $service.Value.Item("image")
                        }
                        if ($null -ne $serviceImage -and $serviceImage.Length -gt 0) {
                            Write-Host "   Found service container image [$($service.Key)]: [$serviceImage]"
                            $actions += [PSCustomObject]@{
                                actionLink = $serviceImage
                                actionRef = $null
                                actionVersionComment = $null
                                workflowFileName = $workflowFileName
                                repo = $repo
                                type = "container-image"
                            }
                        }
                    }
                }

                $steps=$job.Value.Item("steps")
                if ($null -ne $steps) {
                    foreach ($step in $steps) {
                        $uses=$step.Item("uses")
                        if ($null -ne $uses) {
                            # detect docker:// container references (#6)
                            if ($uses.StartsWith("docker://")) {
                                Write-Host "   Found container image used: [$uses]"
                                $actions += [PSCustomObject]@{
                                    actionLink = $uses
                                    actionRef = $null
                                    actionVersionComment = $null
                                    workflowFileName = $workflowFileName
                                    repo = $repo
                                    type = "container-image"
                                }
                            }
                            else {
                                Write-Host "   Found action used: [$uses]"
                                $splitted = $uses.Split("@")
                                $actionLink = $splitted[0]
                                $actionRef = $splitted[1]
                                $actionVersionComment = $splitted[2]

                                $data = [PSCustomObject]@{
                                    actionLink = $actionLink
                                    actionRef = $actionRef
                                    actionVersionComment = $actionVersionComment
                                    workflowFileName = $workflowFileName                                
                                    repo = $repo
                                    type = "action"
                                }

                                $actions += $data
                            }
                        }
                    }
                }
                else {
                    # check for reusable workflow
                    $uses = $job.Value.Item("uses")
                    if ($null -ne $uses) {
                        Write-Host "   Found reusable workflow used: [$uses]"
                        $splitted = $uses.Split("@")
                        $actionLink = $splitted[0]
                        $actionRef = $splitted[1]
                        $actionVersionComment = $splitted[2]

                        $data = [PSCustomObject]@{
                            actionLink = $actionLink
                            actionRef = $actionRef
                            actionVersionComment = $actionVersionComment
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

function GetActionsFromCompositeAction {
    param (
        [string] $content,
        [string] $fileName,
        [string] $repo
    )

    $parsedYaml = ""
    try {
        $parsedYaml = ConvertFrom-Yaml $content
    }
    catch {
        Write-Warning "Error parsing composite action file: [$fileName] in repo: [$repo]"
        return @()
    }

    $actions = @()
    try {
        $runs = $parsedYaml["runs"]
        if ($null -eq $runs) { return $actions }

        $using = $runs.Item("using")
        if ($using -ne "composite") { return $actions }

        $steps = $runs.Item("steps")
        if ($null -eq $steps) { return $actions }

        Write-Host "  Composite action found in [$repo/$fileName]"
        foreach ($step in $steps) {
            $uses = $step.Item("uses")
            if ($null -ne $uses) {
                if ($uses.StartsWith("docker://")) {
                    Write-Host "   Found container image in composite action: [$uses]"
                    $actions += [PSCustomObject]@{
                        actionLink = $uses
                        actionRef = $null
                        actionVersionComment = $null
                        workflowFileName = $fileName
                        repo = $repo
                        type = "container-image"
                    }
                }
                else {
                    Write-Host "   Found action in composite action: [$uses]"
                    $splitted = $uses.Split("@")
                    $actions += [PSCustomObject]@{
                        actionLink = $splitted[0]
                        actionRef = $splitted[1]
                        actionVersionComment = $splitted[2]
                        workflowFileName = $fileName
                        repo = $repo
                        type = "action"
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error processing composite action [$fileName] in repo [$repo]: $_"
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
        # don't return yet — repo may still have a composite action
    }
    
    # create hashtable to store the results in
    $actionsInRepo = @()

    if ($null -ne $workflowFiles -and -not ([string]$workflowFiles).StartsWith("https://docs.github.com/")) {
        Write-Host "Found [$($workflowFiles.Length)] files in the workflows directory"
        foreach ($workflowFile in $workflowFiles) {
            try {
                if ($null -ne $workflowFile.download_url -and $workflowFile.download_url.Length -gt 0 -and $workflowFile.download_url.Split("?")[0].EndsWith(".yml")) { 
                    Write-Host "Loading workflow file: [$($workflowFile.name)]"
                    $workflow = GetRawFile -url $workflowFile.download_url -PAT $PAT -userName $userName
                    $actions = GetActionsFromWorkflow -workflow $workflow -workflowFileName $workflowFile.name -repo $repo

                    $actionsInRepo += $actions
                }
            }
            catch {
                Write-Warning "Error handling this workflow file [$($workflowFile.name)] in repo [$repo]:"
                Write-Host (($workflowFile | ConvertTo-Json -Depth 10) -replace [regex]::Escape($PAT), "****")
                Write-Warning "----------------------------------"
                Write-Host "Error: [$_]"
                Write-Warning "----------------------------------"
                #continue
            }
        }
    }

    # check for composite action files at repo root (action.yml / action.yaml)
    foreach ($actionFileName in @("action.yml", "action.yaml")) {
        try {
            $fileInfo = GetFileInfo -repository $repo -fileName $actionFileName -userName $userName -PAT $PAT
            if ($null -ne $fileInfo -and $null -ne $fileInfo.download_url) {
                Write-Host "Found [$actionFileName] in repo [$repo], checking for composite action"
                $content = GetRawFile -url $fileInfo.download_url -PAT $PAT -userName $userName
                if ($null -ne $content -and $content.Length -gt 0) {
                    $compositeActions = GetActionsFromCompositeAction -content $content -fileName $actionFileName -repo $repo
                    $actionsInRepo += $compositeActions
                }
                break  # don't check action.yaml if action.yml was found
            }
        }
        catch {
            Write-Debug "No [$actionFileName] found in repo [$repo] or error loading it"
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
        $found = $summarized | Where-Object { $_.actionLink -eq $action.actionLink -And $_.type -eq $action.type }
        if ($null -ne $found) {
            # item already found, add this info to it
            $newInfo =  [PSCustomObject]@{
                repo = $action.repo
                workflowFileName = $action.workflowFileName
                actionRef = $action.actionRef
                actionVersionComment = $action.actionVersionComment
            }

            $found.workflows += $newInfo
            $found.count++
        }
        else {
            # new item, create a new object
            $newItem =  [PSCustomObject]@{
                type = $action.type
                actionLink = $action.actionLink
                count = 1
                workflows =  @(
                    [PSCustomObject]@{
                        repo = $action.repo
                        workflowFileName = $action.workflowFileName
                        actionRef = $action.actionRef
                        actionVersionComment = $action.actionVersionComment
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
    Write-Host "- includeArchivedRepos: [$includeArchivedRepos]"

    $includeArchived = $includeArchivedRepos -ne "false"

    # get all repos in an org
    $repos = FindAllRepos -orgName $orgName -userName $userName -PAT $PAT -includeArchived $includeArchived

    # get actions from the workflows in the repos
    $actionsFound = LoadAllUsedActionsFromRepos -repos $repos -userName $userName -PAT $PAT -marketplaceRepo $marketplaceRepo

    if ($actionsFound.Count -gt 0) {
        
        # separate container images from actions/reusable workflows
        $containerImages = $actionsFound | Where-Object { $_.type -eq "container-image" }
        $actionsOnly = $actionsFound | Where-Object { $_.type -ne "container-image" }

        $summarizeActions = SummarizeActionsUsed -actions $actionsOnly

        Write-Host "Found [$($actionsOnly.Count)] actions used in [$($repos.Count)] repos by workflows with [$($summarizeActions.Count) unique actions]"

        # write the actions to disk
        $fileName = "summarized-actions.json"
        $jsonObject = ($summarizeActions | ConvertTo-Json -Depth 10)
        New-Item -Path $fileName -Value $jsonObject -Force | Out-Null
        Write-Host "Stored the summarized usage info into this file: [$fileName] in this directory: [$PWD]"

        # summarize and write container images if any were found
        if ($null -ne $containerImages -and $containerImages.Count -gt 0) {
            $summarizedContainerImages = SummarizeActionsUsed -actions $containerImages
            Write-Host "Found [$($containerImages.Count)] container image references with [$($summarizedContainerImages.Count)] unique images"

            $containerFileName = "container-images.json"
            $containerJsonObject = ($summarizedContainerImages | ConvertTo-Json -Depth 10)
            New-Item -Path $containerFileName -Value $containerJsonObject -Force | Out-Null
            Write-Host "Stored the container images info into this file: [$containerFileName] in this directory: [$PWD]"
        }

        # upload the data into the marketplaceRepo
        #Write-Host "Found [$($actionsFound.actions.Length)] actions in use!"

        # todo: store the json file
        #UploadActionsDataToGitHub -actions $actionsFound -marketplaceRepo $marketplaceRepo -PAT $PAT -repositoryName $repositoryName -repositoryOwner $repositoryOwner
        
        return $summarizeActions
    }

    return $null
}

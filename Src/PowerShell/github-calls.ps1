function Get-Headers {
    param (        
        [string] $userName,
        [string] $PAT
    )

    $pair = "$($userName):$($PAT)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"

    $headers = @{
        Authorization = $basicAuthValue   
        "User-Agent"= $userName     
    }

    return $headers
}

function CallWebRequest {
    param (
        [string] $url,
        [string] $userName,
        [string] $PAT,
        [string] $verbToUse = "Get",
        [object] $body,
        [boolean] $skipWarnings = $false
    )

    if ([string]::IsNullOrEmpty($userName)) {
        throw "userName cannot be null or empty"
    }
    if ([string]::IsNullOrEmpty($PAT)) {
        throw "PAT cannot be null or empty"
    }
    if ([string]::IsNullOrEmpty($url)) {
        throw "url cannot be null or empty"
    }    

    $Headers = Get-Headers -userName $userName -PAT $PAT
    Write-Host "Calling api on url [$url]"

    try {
        $bodyContent = ($body | ConvertTo-Json) -replace '\\', '\'
        if ($verbToUse -eq "Get") {
            $result = Invoke-WebRequest -Uri $url -Headers $Headers -Method $verbToUse -ErrorAction Stop
        }
        else {
            $result = Invoke-WebRequest -Uri $url -Headers $Headers -Method $verbToUse -Body $bodyContent -ErrorAction Stop
        }
        
        Write-Debug "  StatusCode: $($result.StatusCode)"
        Write-Debug "  RateLimit-Limit: $($result.Headers["X-RateLimit-Limit"])"
        Write-Debug "  RateLimit-Remaining: $($result.Headers["X-RateLimit-Remaining"])"
        Write-Debug "  RateLimit-Reset: $($result.Headers["X-RateLimit-Reset"])"
        Write-Debug "  RateLimit-Used: $($result.Headers["x-ratelimit-used"])"
                
        # convert the response json content
        $info = ($result.Content | ConvertFrom-Json)
    
        
        $LinkHeader = $result.Headers["Link"]
        Write-Debug "  Paging links: $($LinkHeader)"
        # Test for paging links and try to enumerate all pages
        if ($null -ne $LinkHeader) {
            #Write-Warning "Paging link detected:"
            foreach ($page in $LinkHeader.Split(",")) {
                            
                #Write-Host "Found page: [$page]"
                #Write-Host "rel next found at: [$($page.Split(";")[1])" 

                if ($page.Split(";")[1].Trim() -eq 'rel="next"') {
                    #Write-Host "Next page is at [$page]"
                    $almostUrl = $page.Split(";")[0].Trim()
                    #Write-Host "Almost: $almostUrl"
                    $linkUrl = $almostUrl.Substring(1, $almostUrl.Length - 2)
                    Write-Host "Handling pagination link with next page at: $linkUrl"

                    $nextPageInfo = CallWebRequest -url $linkUrl -userName $userName -PAT $PAT
                    
                    $info += $nextPageInfo
                    return $info
                }
            }
        }

        return $info
    }
    catch {
        try {
            $messageData = $_.ErrorDetails.Message | ConvertFrom-Json
        }
        catch {
            Write-Error "Error calling api on [$url]:"
            Write-Error "Error: " $_
            Write-Error "ErrorDetails: " $_.ErrorDetails
        }

        if ($false -eq $skipWarnings) {
            Write-Host "Error calling api at [$url]:"
            Write-Host "  StatusCode: $($_.Exception.Response.StatusCode)"
            Write-Host "  RateLimit-Limit: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Limit"))"
            Write-Host "  RateLimit-Remaining: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Remaining"))"
            Write-Host "  RateLimit-Reset: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Reset"))"
            Write-Host "  RateLimit-Used: $($_.Exception.Response.Headers.GetValues("x-ratelimit-used"))"
            
            Write-Host "Message: $($_.ErrorDetails.Message)"
            if ($messageData.message.StartsWith("API rate limit exceeded")) {
                Write-Error "Rate limit exceeded. Halting execution"
               throw
            }
            
            Write-Host "$messageData"
        }
        if ($messageData.message -eq "Not Found" -or $messageData.message -eq "This repository is empty.") {
            if ($false -eq $skipWarnings) {
                Write-Warning "Call to GitHub Api [$url] had [not found] result with documentation url [$($messageData.documentation_url)]"
            }
            return $messageData.documentation_url
        }

        if ($messageData.message.StartsWith("API rate limit exceeded")) {
            Write-Error "Rate limit exceeded. Halting execution"
            throw
        }
    }

    return "General Error loading from url [$url]"
}

function GetForkCloneUrl {
    param (
        [string] $forkUrl,
        [string] $PAT
    )

    return "https://xx:$PAT@github.com/$fork.git"
}

function GetGitHubUrl {
    param (
        [string] $url
    )

    if ($url.StartsWith("/")) {
        # remove / from the start of the url
        $url = $url.Substring(1, $url.Length - 1)
    }

    $apiUrl = $env:GITHUB_API_URL
    if ($null -eq $apiUrl) {
        # assume we are hitting the SaaS version of GitHub
        $apiUrl = "https://api.github.com"
    }

    return "$apiUrl/$url"
}

function GetParentInfo {
    param (
        [string] $fork,
        [string] $PAT
    )

    $repoUrl = GetGitHubUrl "repos/$fork"
    $info = CallWebRequest -url $repoUrl -userName $userName -PAT $PAT

    if ($false -eq $info.fork) {
        Write-Error "Repo [$fork] is not a fork"
        throw
    }

    return [PSCustomObject]@{
        parentUrl = $info.parent.git_url
        parentDefaultBranch = $info.parent.default_branch
    }

}

function GetAllFilesInPath {
    param (
        [string] $repository,
        [string] $path,
        [string] $userName,
        [string] $PAT
    )

    Write-Host "Checking if there are files in the path [$path] in repository [$repository]"

    #force testing with private repo:
    #$repository = "rajbos/k8s-actions-runner-test"
    $url = GetGitHubUrl "repos/$repository/contents/$path"
    $info = CallWebRequest -url $url -userName $userName -PAT $PAT -skipWarnings $true

    return $info
}

function GetFileInfo {
    param (
        [string] $repository,
        [string] $fileName,
        [string] $userName,
        [string] $PAT
    )

    Write-Host "Checking if the file [$fileName] exists in repository [$repository]"
    $url = GetGitHubUrl "repos/$repository/contents/$fileName"
    $info = CallWebRequest -url $url -userName $userName -PAT $PAT -skipWarnings $true

    return $info
}

function GetBranchInfo {
    param (
        [string] $parent,
        [string] $PAT,
        [string] $branchName
    )

    $repoUrl = GetGitHubUrl "repos/$parent/branches/$branchName"
    $info = CallWebRequest -url $repoUrl -userName $userName -PAT $PAT

    return $info.commit.commit.author.date
}

function AddCommentToIssue {
    param (
        [string] $repoName,
        [string] $message,
        [int] $number,
        [string] $userName,
        [string] $PAT
    )

    $url = GetGitHubUrl "repos/$repoName/issues/$number/comments"

    $body = [PSCustomObject]@{
        body = $message
    }

    CallWebRequest -url $url -userName $userName -PAT $PAT -body $body -verbToUse "POST"
}


function CloseIssue {
    param (
        [string] $issuesRepositoryName,
        [int] $number,
        [string] $userName,
        [string] $PAT
    )    

    $url = GetGitHubUrl "repos/$issuesRepositoryName/issues/$number"

    $data = [PSCustomObject]@{       
        state = "closed"
    }

    Write-Host "Closing issue with number [$number] in repository [$issuesRepositoryName]"
    $result = CallWebRequest -url $url -verbToUse "POST" -body $data -PAT $PAT -userName $userName

    Write-Host "Issue has been closed and can be found at this url: ($($result.html_url))"
}


function CreateNewIssueForRepo { 
    param (
        [Object] $repoInfo,
        [string] $issuesRepositoryName,
        [string] $title,
        [string] $body,
        [string] $PAT,
        [string] $userName
    )

    $url = GetGitHubUrl "repos/$issuesRepositoryName/issues"

    $data = [PSCustomObject]@{
        title = $title
        body = $body
    }

    Write-Host "Creating a new issue with title [$title] in repository [$issuesRepositoryName]"
    $result = CallWebRequest -url $url -verbToUse "POST" -body $data -PAT $PAT -userName $userName

    Write-Host "Issue has been created and can be found at this url: ($($result.html_url))"
}

function FindAllRepos {
    param (
        [string] $orgName,
        [string] $userName,
        [string] $PAT
    )

    # todo: add support for pagination
    # check if we can find all repos that are forks with this call, so we can retrieve the normal repos with a GraphQL query (which could include the information if the repo has workflow files

    # check if we have an org with repos available, or that we have a user account that we need to get all repos for
    $url = GetGitHubUrl "/orgs/$orgName/repos"
    $info = CallWebRequest -url $url -userName $userName -PAT $PAT

    if ($info.GetType() -eq [string] -And $info.StartsWith("https://docs.github.com/")) {
        Write-Warning "Error loading information from org with name [$orgName], trying with user based repository list"
        $url = GetGitHubUrl "users/$orgName/repos"
        $info = CallWebRequest -url $url -userName $userName -PAT $PAT -skipWarnings $true
    }

    Write-Host "Found [$($info.Count)] repositories in [$orgName]"
    return $info
}

function GetRawFile {
    param (
        [string] $url,
        [string] $PAT,
        [string] $userName
    )

    if ($null -eq $PAT -or $PAT.Length -eq 0) {
        Write-Warning "Cannot handle empty PAT"
        return ""
    }

    if ($null -eq $userName -or $userName.Length -eq 0) {
        Write-Warning "Cannot handle empty userName"
        return ""
    }

    if ($null -eq $url) {
        Write-Warning "Cannot handle empty url"
        return ""
    }
    $index = $url.IndexOf("?token=")
    $logUrl = "" 
    if ($index -gt 0) {
        $logUrl = $url.Substring(0, $index)
    }
    else {
        $logUrl = $url
    }
   
    $Headers = Get-Headers -userName $userName -PAT $PAT
    $requestResult = ""
    try {
        $requestResult = Invoke-WebRequest -Uri $url -Headers $Headers -Method Get -ErrorAction Stop
    }
    catch {
        Write-Warning "Error loading file content response from url [$($logUrl)]"
        Write-Warning "Error: [$_]"
        return ""
    }

    try {
        $result = $requestResult.Content
        $output = ""
        # remove any empty lines or tabs in the result to prevent issues with parsing yaml
        foreach ($line in $result.Split([Environment]::NewLine)) {
            $trimmedLine = $line.Trim().Replace("`t", "").Replace(" ", "")
            if ($trimmedLine.Length -gt 0) {
                $output += $line + [Environment]::NewLine
            }
        }
        return $output
    }
    catch {
        Write-Warning "Error converting file content from url [$($logUrl)]"
        Write-Warning "Error: [$_]"
        Write-Warning "Content: [$requestResult]"
        return ""
    }
}

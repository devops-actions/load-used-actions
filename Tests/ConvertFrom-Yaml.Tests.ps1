BeforeAll {
    Import-Module "powershell-yaml" -Force
    . ./Src/PowerShell/load-used-actions.ps1 -orgName "test" -PAT "test-pat"
}

Describe "Test conversion with multiple indentation" {
    It "Extra indentations" {

        Write-Host $PSScriptRoot
        $content = Get-Content "Tests/Files/extra-indentation.yml" -Raw
        $result = ConvertFrom-Yaml $content

        $result["jobs"].GetEnumerator().Length | Should -Be 1
        foreach ($job in $result["jobs"].GetEnumerator()) {
            $stepLength = 0
            $steps = $job.Value.Item("steps")
            foreach ($step in $steps) {
                $stepLength++    
            }
            $stepLength | Should -Be 3
        }        
    }
}

Describe "Test conversion with normal indentation" {
    It "Normal indentations" {

        Write-Host $PSScriptRoot
        $content = Get-Content "Tests/Files/normal-indentation.yml" -Raw
        $result = ConvertFrom-Yaml $content

        $result["jobs"].GetEnumerator().Length | Should -Be 1
        foreach ($job in $result["jobs"].GetEnumerator()) {
            $stepLength = 0
            $steps = $job.Value.Item("steps")
            foreach ($step in $steps) {
                $stepLength++    
            }
            $stepLength | Should -Be 3
        }
    }

    It "Slim indentation"  {    
        Write-Host $PSScriptRoot
        $content = Get-Content "Tests/Files/rajbos-actions-demo_deploy-cloudrun.yml" -Raw
        $result = ConvertFrom-Yaml $content

        $jobCount = 0
        foreach ($job in $result["jobs"].GetEnumerator()) {
            $jobCount++

            $stepLength = 0
            $steps = $job.Value.Item("steps")
            foreach ($step in $steps) {
                $stepLength++    
            }
            switch ($job.Key) { # jobs are not ordered as in the file
                "gcloud"   { $stepLength | Should -Be 7 -Because "$($job.Key) should have 5 steps"}
                "b64_json" { $stepLength | Should -Be 7 -Because "$($job.Key) should have 7 steps" }
                "json"     { $stepLength | Should -Be 7 -Because "$($job.Key) should have 7 steps" }
                "cleanup"  { $stepLength | Should -Be 2 -Because "$($job.Key) should have 2 steps" }
            }
        }
        $jobCount | Should -Be 4
    }
}

Describe "Test container image detection" {
    It "Should detect docker:// step references, job containers, and service images" {
        $content = Get-Content "Tests/Files/container-images.yml" -Raw
        $actions = GetActionsFromWorkflow -workflow $content -workflowFileName "container-images.yml" -repo "test/repo"

        $containerImages = $actions | Where-Object { $_.type -eq "container-image" }
        $regularActions = $actions | Where-Object { $_.type -eq "action" }

        # should find 5 container images: node:18-alpine, redis:7, postgres:15, docker://ghcr.io/..., python:3.12-slim
        $containerImages.Count | Should -Be 5

        # should find 2 regular actions: actions/checkout@v4 (twice)
        $regularActions.Count | Should -Be 2

        # verify docker:// reference was detected
        $dockerRef = $containerImages | Where-Object { $_.actionLink -like "docker://*" }
        $dockerRef | Should -Not -BeNullOrEmpty
        $dockerRef.actionLink | Should -Be "docker://ghcr.io/some-org/some-tool:latest"

        # verify job container images were detected
        $nodeImage = $containerImages | Where-Object { $_.actionLink -eq "node:18-alpine" }
        $nodeImage | Should -Not -BeNullOrEmpty

        $pythonImage = $containerImages | Where-Object { $_.actionLink -eq "python:3.12-slim" }
        $pythonImage | Should -Not -BeNullOrEmpty

        # verify service images were detected
        $redisImage = $containerImages | Where-Object { $_.actionLink -eq "redis:7" }
        $redisImage | Should -Not -BeNullOrEmpty
    }
}
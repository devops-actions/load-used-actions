BeforeAll {
    Import-Module "powershell-yaml" -Force
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
            switch ($jobCount) {
                0 { $stepLength | Should -Be 5 -Because "$($job.Key) should have 5 steps"}
                1 { $stepLength | Should -Be 7 -Because "$($job.Key) should have 7 steps" }
                2 { $stepLength | Should -Be 7 -Because "$($job.Key) should have 7 steps" }
                3 { $stepLength | Should -Be 2 -Because "$($job.Key) should have 2 steps" }
            }
        }
        $jobCount | Should -Be 4
    }
}
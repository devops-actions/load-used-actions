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
}
# set up environment variables

$Global:PAT
$Global:userName

BeforeAll {
    $Global:PAT = $env:GITHUB_TOKEN
    $Global:userName = "rajbos"

    Import-Module "powershell-yaml" -Force
    # pull in central calls library
    . .\Src\PowerShell\github-calls.ps1
    . .\Src\PowerShell\load-used-actions.ps1 -orgName "rajbos-actions" -userName "rajbos" -marketplaceRepo "rajbos/actions-marketplace" -PAT $Global:PAT
}

Describe "Download OSSF workflow" {
    It "Parse yaml" {
        $url = "https://raw.githubusercontent.com/devops-actions/load-used-actions/main/.github/workflows/ossf-analysis.yml"

        $workflow = GetRawFile -url $url -PAT $Global:PAT -userName $Global:userName

        $workflow | Should -Not -BeNullOrEmpty
        $workflow.Replace(" ", "") | Should -Not -BeNullOrEmpty

    }
}

Describe "Download Cloudrun workflow" {
    It "Parse yaml" {
        $url = "https://raw.githubusercontent.com/rajbos-actions-demo/deploy-cloudrun/main/.github/workflows/deploy-cloudrun.yml"

        $workflow = GetRawFile -url $url -PAT $Global:PAT -userName $Global:userName

        $workflow | Should -Not -BeNullOrEmpty
        $workflow.Replace(" ", "") | Should -Not -BeNullOrEmpty
        $actions = GetActionsFromWorkflow -workflow $workflow -workflowFileName "deploy-cloudrun.yml" -repo "rajbos-actions-demo/deploy-cloudrun"
        $actions | Should -Not -BeNullOrEmpty
        $actions.Count | Should -Be 3
    }
}
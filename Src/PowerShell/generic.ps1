$moduleName = "powershell-yaml"

# install a yaml parsing module (already done in the container image)
if($env:computername -ne "ROB-XPS9700") {
    Write-Host "PSHOME: [$pshome]" 

    # check if module is installed locally:
    $module = Get-Module -name $moduleName
    if ($null -eq $module) {
        Write-Host "Module [$moduleName] not found, installing it"
        Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber
    }
    else {
        Write-Host "Module [$moduleName] found, skipping installation"
    }

    # add back the root folder to the modules path because GitHub runner seems to overwite it
    $env:PSModulePath += ":/root/.local/share/powershell/Modules"

    Write-Host "PSModulePath:"
    foreach ($path in $env:PSModulePath -split ':') {
        Write-Host "- [$path]"
    }
    try {
        Write-Host "Importing module for the yaml parsing"
        Import-Module powershell-yaml -Force
    }
    catch {
        Write-Warning "Error during importing of the yaml module needed for parsing"
        Write-Warning $_
    }
}
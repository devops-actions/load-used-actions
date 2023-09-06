$moduleName = "powershell-yaml"

if ($null -eq $env:DOCKER -Or $false -eq $env:DOCKER -Or $env:DOCKER -eq "false") {
    Write-Host "Not running in a container, check to see if we need to install [$moduleName]"
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
        # first check if module path already has this value:
        if ($false -eq ($env:PSModulePath -like "/root/.local/share/powershell/Modules")) {
            $env:PSModulePath += ":/root/.local/share/powershell/Modules"
        }

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
}
else {
    Write-Host "Running in a container, [$moduleName] already installed in the base image"
    # double check then!
    $module = Get-Module -name $moduleName
    if ($null -eq $module) {
        Write-Host "Module [$moduleName] not found!"
    }
    else {
        Write-Host "Module [$moduleName] found"
    }
}
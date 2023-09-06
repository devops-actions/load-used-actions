$moduleName = "powershell-yaml"

# add back the root folder to the modules path because GitHub runner seems to overwite it
# first check if module path already has this value:
if ($false -eq ($env:PSModulePath -like "/root/.local/share/powershell/Modules")) {
    $env:PSModulePath += ":/root/.local/share/powershell/Modules"
}

try {
    Write-Host "Importing module for the yaml parsing"
    Import-Module powershell-yaml -Force
}
catch {
    Write-Warning "Error during importing of the yaml module needed for parsing:"
    Write-Warning $_

    Write-Host "Trying to install the module, internet connection needed:"
    try {
        Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber
    }
    catch {
        Write-Warning "Error during installation of the yaml module needed for parsing:"
        Write-Warning $_
        return
    }
}
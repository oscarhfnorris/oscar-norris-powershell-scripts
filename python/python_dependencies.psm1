<#
    .SYNOPSIS
        Module to install dependencies using pip or conda.

    .DESCRIPTION
        This module provides functions to install dependencies using pip or conda. It also includes functions to create and manage virtual environments.

    .NOTES
        File Name      : install_dependencies.ps1
        Author         : Oscar Norris
        Prerequisite   : PowerShell 7.0 or higher, Python 3.6 or higher, conda (optional)

    .EXAMPLE
        Install-DependenciesScript -UseVenv
        This command installs dependencies using venv.
#>

<#
.SYNOPSIS
    Finds the Python executable.

.DESCRIPTION
    This function finds the Python executable on the system, preferring 'python' over 'python3'.

.RETURNS
    The name of the Python executable.
#>
function Find-Python {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        return "python"
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        return "python3"
    } else {
        Write-Error "python or python3 not found. Please install Python."
        exit 1
    }
}

<#
.SYNOPSIS
    Finds the pip executable.

.DESCRIPTION
    This function finds the pip executable on the system, preferring 'pip3' over 'pip'.

.RETURNS
    The name of the pip executable.
#>
function Find-Pip {
    if (Get-Command pip3 -ErrorAction SilentlyContinue) {
        return "pip3"
    } elseif (Get-Command pip -ErrorAction SilentlyContinue) {
        return "pip"
    } else {
        Write-Error "pip or pip3 not found. Please install pip."
        exit 1
    }
}

<#
.SYNOPSIS
    Creates a virtual environment.

.DESCRIPTION
    This function creates a virtual environment using the specified Python executable.

.PARAMETER Python
    The Python executable to use for creating the virtual environment.

.PARAMETER VenvPath
    The path where the virtual environment should be created.
#>
function New-Venv {
    param (
        [string]$Python,
        [string]$VenvPath
    )
    & $Python -m venv $VenvPath
}

<#
.SYNOPSIS
    Activates a virtual environment.

.DESCRIPTION
    This function activates a virtual environment at the specified path.

.PARAMETER VenvPath
    The path to the virtual environment to be activated.
#>
function Enable-Venv {
    param (
        [string]$VenvPath
    )
    $osPlatform = [System.Environment]::OSVersion.Platform
    if ($osPlatform -eq [System.PlatformID]::Win32NT) {
        $activatePath = "$VenvPath\Scripts\Activate.ps1"
    } else {
        $activatePath = "$VenvPath/bin/Activate.ps1"
    }
    & $activatePath
}

<#
.SYNOPSIS
    Removes an existing virtual environment.

.DESCRIPTION
    This function removes an existing virtual environment at the specified path.

.PARAMETER VenvPath
    The path to the virtual environment to be removed.
#>
function Remove-Venv {
    param (
        [string]$VenvPath
    )
    if (Test-Path $VenvPath) {
        Remove-Item -Recurse -Force $VenvPath
    }
}

<#
.SYNOPSIS
    Creates a conda environment.

.DESCRIPTION
    This function creates a conda environment with the specified Python version.

.PARAMETER PythonVersion
    The version of Python to use for the conda environment.

.PARAMETER CondaEnvPath
    The path where the conda environment should be created.
#>
function New-CondaEnv {
    param (
        [string]$PythonVersion,
        [string]$CondaEnvPath
    )
    & conda deactivate
    & conda init powershell
    & conda create -y --prefix $CondaEnvPath python=$PythonVersion
    & conda activate $CondaEnvPath

    # Install python and pip in the conda environment
    & conda install -y python=$PythonVersion pip
    & conda install -y pip
}

<#
.SYNOPSIS
    Removes an existing conda environment.

.DESCRIPTION
    This function removes an existing conda environment at the specified path.

.PARAMETER CondaEnvPath
    The path to the conda environment to be removed.
#>
function Remove-CondaEnv {
    param (
        [string]$CondaEnvPath
    )
    if (Test-Path $CondaEnvPath) {
        & conda env remove --prefix $CondaEnvPath -y
    }
}

<#
.SYNOPSIS
    Installs dependencies using pip.

.DESCRIPTION
    This function installs dependencies listed in a requirements file using pip.

.PARAMETER Pip
    The pip executable to use for installing dependencies.

.PARAMETER RequirementsPath
    The path to the requirements file.
#>
function Install-Dependencies {
    param (
        [string]$Pip,
        [string]$RequirementsPath
    )
    & $Pip install --upgrade pip
    & $Pip install -r $RequirementsPath
}

<#
.SYNOPSIS
    Checks for outdated dependencies and writes the results to a JSON file.

.DESCRIPTION
    This function checks for outdated dependencies listed in a requirements file and outputs the results to a JSON file.

.PARAMETER Pip
    The pip executable to use for checking outdated dependencies.

.PARAMETER RequirementsPath
    The path to the requirements file.

.PARAMETER OutdatedFilePath
    The path to the JSON file where outdated dependencies will be written.
#>
function Get-OutdatedDependencies {
    param (
        [string]$Pip,
        [string]$RequirementsPath,
        [string]$OutdatedFilePath
    )
    $outdatedPackages = & $Pip list --outdated --format=json | ConvertFrom-Json
    $dependencies = Get-Content $RequirementsPath | ForEach-Object { $_.Split('==')[0] }
    $outdatedDependencies = $outdatedPackages | Where-Object { $dependencies -contains $_.name -and $_.name -ne "pip" }

    if ($outdatedDependencies.Count -gt 0) {
        $outdatedDependencies | ConvertTo-Json | Out-File -FilePath $OutdatedFilePath -Encoding utf8
        Write-Host "The following packages are outdated:" -ForegroundColor Yellow
        foreach ($package in $outdatedDependencies) {
            $outdatedInfo = "$($package.name) (Current: $($package.version), Latest: $($package.latest_version))"
            Write-Host $outdatedInfo -ForegroundColor Yellow
        }
    } else {
        @{} | ConvertTo-Json | Out-File -FilePath $OutdatedFilePath -Encoding utf8
        Write-Host "All packages are up to date." -ForegroundColor Green
        Remove-Item -Path $OutdatedFilePath
    }
}

<#
.SYNOPSIS
    Main script to install dependencies.

.DESCRIPTION
    This script sets up a Python conda environment or virtual environment and installs all dependencies listed in the requirements.txt file.

.PARAMETER EnvPath
    The path to the environment (either venv or conda) to be created.

.PARAMETER UseVenv
    If specified, the script will use venv to create and manage the environment. Otherwise, it will use conda.
#>
function Install-DependenciesScript {
    param (
        [string]$EnvPath = (Join-Path -Path $PSScriptRoot -ChildPath ".."),
        [switch]$UseVenv
    )

    Push-Location $EnvPath

    $venvPath = Join-Path -Path $EnvPath -ChildPath ".venv"
    $condaEnvPath = Join-Path -Path $EnvPath -ChildPath ".conda"
    $requirementsPath = Join-Path -Path $PSScriptRoot -ChildPath "dependencies.txt"
    $outdatedFilePath = Join-Path -Path $PSScriptRoot -ChildPath "outdated_dependencies.json"

    Remove-Venv -VenvPath $venvPath
    Remove-CondaEnv -CondaEnvPath $condaEnvPath

    $python = Find-Python

    if ($IsMacOS -and (Test-Path "/opt/homebrew/bin")) {
        $env:PATH = "/opt/homebrew/bin:" + $env:PATH
    }

    $pythonVersion = & $python --version 2>&1
    if ($pythonVersion -is [string]) {
        $pythonVersion = $pythonVersion.Split(' ')[1]
    } else {
        Write-Error "Failed to retrieve Python version. Output: $pythonVersion"
        exit 1
    }

    if ($UseVenv) {
        New-Venv -Python $python -VenvPath $venvPath
        Enable-Venv -VenvPath $venvPath
    } else {
        New-CondaEnv -PythonVersion $pythonVersion -CondaEnvPath $condaEnvPath
    }

    $pip = Find-Pip
    Install-Dependencies -Pip $pip -RequirementsPath $requirementsPath
    Get-OutdatedDependencies -Pip $pip -RequirementsPath $requirementsPath -OutdatedFilePath $outdatedFilePath

    Pop-Location

    if ($UseVenv) {
        deactivate
    } else {
        & conda deactivate
    }
}

Export-ModuleMember -Function Find-Python, Find-Pip, New-Venv, Enable-Venv, Remove-Venv, New-CondaEnv, Remove-CondaEnv, Install-Dependencies, Get-OutdatedDependencies, Install-DependenciesScript
# Install Python dependencies for the project
Import-Module $PSScriptRoot\python_dependencies.psm1 -Force

Install-DependenciesScript -UseVenv

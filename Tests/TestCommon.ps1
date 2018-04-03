# Load module from the local filesystem, instead from the ModulePath
Remove-Module Posh-AwsEasy -Force -ErrorAction SilentlyContinue
Import-Module (Split-Path $PSScriptRoot -Parent)

$Script:ModuleName = 'Posh-AwsEasy'
$script:FunctionPath = Resolve-Path (Join-Path $PSScriptRoot '../Functions')

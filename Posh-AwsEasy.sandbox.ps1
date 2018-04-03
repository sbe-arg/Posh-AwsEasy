Clear-Host
Remove-Module Posh-AwsEasy -Force -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot -Verbose
cd $PSScriptRoot
Get-Module PSScriptAnalyzer

# script analyze functions?
$questionsa = Read-Host "Run checks? (yes/no)"
if($questionsa -like "y*"){
    $checks = Get-ChildItem .\Tests\Module\*.ps1
    foreach($check in $checks){
        & $check.FullName
    }
}
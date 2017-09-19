Write-Verbose "Posh-AwsEasy module"
Write-Verbose 'Doing stuff...'

# load functions
  $functionFilter = Join-Path $PSScriptRoot "Functions"
  Get-ChildItem -Path $functionFilter -Filter "*.ps1" -Recurse |
  Foreach-Object {
      Write-Verbose "Loading function $($_.Name).."
      . $_.FullName
  }

Write-Verbose 'Done!'

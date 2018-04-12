<#
.SYNOPSIS
    Edit text files directly from bucket.
.DESCRIPTION
    Only text and non-encrypted.
.EXAMPLE
    $BucketName = 'test-mybucket'
    $KeyPrefix = 'folder1/subfolder3' # folder/folder/folder
    $Key = 'test.txt' # filename
    $Region = 'ap-southeast-2'

    Edit-S3Object -BucketName $BucketName -KeyPrefix $KeyPrefix -Key $Key -Region $Region -Editor
#>

function Edit-S3Object {
  [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
  param(
    [Parameter(Mandatory)][string]$BucketName,
    [Parameter(Mandatory)][string]$KeyPrefix,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][ValidateSet("notepad","atom","notepad++","code")][string]$Editor,
    [Parameter(Mandatory)][string]$Region
  )
  begin{

    $TempFile = [System.IO.Path]::GetTempFileName()

    function Get_S3Object() {
      param(
          [string]$Region,
          [string]$BucketName,
          [string]$KeyPrefix,
          [string]$Key,
          [string]$TempFile
      )
      Set-DefaultAWSRegion -Region $Region
      Write-Verbose "Getting file $BucketName/$KeyPrefix/$Key from $Region."
      try{ Read-S3Object -BucketName $BucketName -Key $keyPrefix/$Key -File $TempFile -Region $Region | Out-Null }
      catch{ Write-Warning "No $Key found in $BucketName/$KeyPrefix. Will create a new file." }
      return $TempFile
    } #end get_s3object

    function Edit_Object() {
      param(
          [string]$Editor,
          [string]$Object,
          [string]$Key
      )
      Write-Warning "Using $Editor to open $Key."
      Start-Process -FilePath $Editor -ArgumentList $Object -Wait
    } # end edit_object

    function Save_S3Object() {
       param(
        [string]$Region,
        [string]$BucketName,
        [string]$KeyPrefix,
        [string]$Key,
        [string]$TempFile
      )
      Set-DefaultAWSRegion -Region $Region
      Write-Verbose "Uploading new version of object $Key on $BucketName/$KeyPrefix in $Region."
      Write-S3Object -BucketName $BucketName -Key $KeyPrefix/$Key -File $TempFile -Region $Region | Out-Null
      Remove-Item -Path $TempFile -Force
      Write-Warning "Uploaded file to $BucketName/$KeyPrefix/$Key in $Region."
    }
  } # end begin
  process {
    if($PSCmdlet.ShouldProcess("Getting file $BucketName/$KeyPrefix/$Key from $Region.")){
      Get_S3Object -Region $Region -BucketName $BucketName -KeyPrefix $KeyPrefix -Key $Key -TempFile $TempFile
    }
    if($PSCmdlet.ShouldProcess("Using $Editor to open $Key.")){
      Edit_Object -Editor $Editor -Object $TempFile -Key $Key
    }
    if($PSCmdlet.ShouldProcess("Uploading new version of object $Key on $BucketName/$KeyPrefix in $Region.")){
      Save_S3Object $Region -BucketName $BucketName -KeyPrefix $KeyPrefix -Key $Key -TempFile $TempFile
    }
  } # end process
}

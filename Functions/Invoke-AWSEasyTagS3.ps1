# http://docs.aws.amazon.com/powershell/latest/reference/index.html?page=AWS_Resource_Groups_Tagging_API_cmdlets.html&tocid=AWS_Resource_Groups_Tagging_API_cmdlets

function Invoke-AwsEasyTagS3 {
  param(
    [string]$region = (Get-EC2InstanceMetadata -Category Region | Select -ExpandProperty SystemName),
    [string]$tagkey,
    [string]$tagvalue,
    [string]$filter
  )

  process{
    # do all buckets
    $buckets = Get-S3Bucket -region $region | where {$_.BucketName -like "*$filter*"}
    foreach($b in $buckets){
      $arn = "arn:aws:s3:::$($b.BucketName)"
      $tags = Get-S3BucketTagging -BucketName $b.BucketName | where {$_.key -eq $tagkey -and $_.Value -eq $tagvalue}
      $tcount = $tags.count
      if($tcount -eq 1){
        foreach($t in $tags){
          write-warning "$($b.BucketName) tag: $($t.key) = $($t.value)"
        }
      }
      else{
        Invoke-AwsEasyTag -arn $arn -tagkey $tagkey -tagvalue $tagvalue -addtag -region $region
        write-warning "$($b.BucketName)"
      }
    }
  }
}

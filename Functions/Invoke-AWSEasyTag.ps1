# http://docs.aws.amazon.com/powershell/latest/reference/index.html?page=AWS_Resource_Groups_Tagging_API_cmdlets.html&tocid=AWS_Resource_Groups_Tagging_API_cmdlets

<#
.SYNOPSIS
    Tag all resoruces or remove/update a tag on all resources
.DESCRIPTION
    Tagger for all resources no filter so be carefull.
.EXAMPLE
    Invoke-AwsEasyTag -tagkey mytag -region $region -tagvalue myvalue -addtag
    Invoke-AwsEasyTag -tagkey mytag -region $region -removetag
    Invoke-AwsEasyTag -tagkey mytag -region $region -tagvalue myvalue -updatetag
#>

function Invoke-AwsEasyTag {
  param(
    [string]$region = (Get-EC2InstanceMetadata -Category Region | Select -ExpandProperty SystemName),
    [string]$tagkey,
    [string]$tagvalue,
    [switch]$addtag,
    [switch]$updatetag,
    [switch]$removetag,
    [switch]$showresources,
    [switch]$showmissingresources,
    [string]$arn
  )

  process{
    # GET resources
    $totalresources = Get-RGTResource -Region $region
    if(($addtag -and $updatetag) -or ($removetag -and $updatetag) -or ($removetag -and $addtag) ){
      Write-Warning "You can't more than one statement add/remove/update."
      break
    }
    elseif(-not $tagvalue -and $tagkey){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "not-allowed"
      Write-Warning "Resources using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region
      Write-Warning "Found $(($totalresources).count - ($resources).count) resources are missing tag:$tagkey"
      Write-Warning "Show resources missing tag:$tagkey using -showmissingresources."
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
      if($showmissingresources){
        $totalresources | Get-AwsEasyTags | select ResourceARN,$tagkey | sort -descending $tagkey
      }
    }
    elseif($tagkey -and $tagvalue -and $updatetag){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Resources using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    elseif($tagkey -and $tagvalue -and $addtag){
      # required for add
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Getting resources..."
      $resources = Get-RGTResource -ResourceType $resourcetype -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    elseif(-not $addtag -and $tagkey -and $tagvalue){
      # required for delete/update
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Resources using key:$tagkey value:$tagvalue..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey"; Values="$tagvalue" } -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    else{
      $cando = "not-allowed"
      Write-Warning "Getting resources..."
      $resources = Get-RGTResource -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count)"
      $tagged
    }

    if($arn){
      $resources.ResourceARN = $arn
      Write-Warning "Arn set to $($resources.ResourceARN)"
    }

    # UPDATE tag
    if($updatetag -and $cando -eq "allowed"){
      if($tagkey -eq "Name"){
        Write-Warning "Don't play with fire. You cannot change Tag.Name as is the default aws tag."
        break
      }
      Write-Warning "Resources: $(($resources).count)"
      foreach($r in $resources){
        Write-Warning "Updating tag:$tagkey value:$tagvalue on $(($r).ResourceARN)"
        $r.ResourceARN | Add-RGTResourceTag -Tag @{ "$tagkey"="$tagvalue" } -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($addtag -and $cando -eq "not-allowed"){
      Write-Warning "Command -addtag requires -tagvalue -tagkey"
      break
    }

    # ADD tag
    if($addtag -and $cando -eq "allowed"){
      if($tagkey -eq "Name"){
        Write-Warning "Don't play with fire. You cannot change Tag.Name as is the default aws tag."
        break
      }
      Write-Warning "Resources: $(($resources).count)"
      foreach($r in $resources){
        Write-Warning "Adding tag:$tagkey value:$tagvalue on $(($r).ResourceARN)"
        $r.ResourceARN | Add-RGTResourceTag -Tag @{ "$tagkey"="$tagvalue" } -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($addtag -and $cando -eq "not-allowed"){
      Write-Warning "Command -addtag requires -tagvalue -tagkey"
      break
    }

    # REMOVE tag
    if($removetag -and $cando -eq "allowed"){
      if($tagkey -eq "Name"){
        Write-Warning "Don't play with fire. You cannot change Tag.Name as is the default aws tag."
        break
      }
      Write-Warning "Resources: $(($resources).count)"
      foreach($r in $resources){
        Write-Warning "Removing tag:$tagkey on $(($r).ResourceARN)"
        $r.ResourceARN | Remove-RGTResourceTag -TagKey $tagkey -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($removetag -and $cando -eq "not-allowed"){
      Write-Warning "Command -removetag requires -tagvalue -tagkey"
      break
    }

    if($showresources){
      $resources.ResourceARN
    }
  }
}

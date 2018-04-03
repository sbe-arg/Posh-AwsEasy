<#
.SYNOPSIS
    Tag all resoruces or remove/update a tag on all resources.
.DESCRIPTION
    Tagger for all resources no filter so be carefull.
    http://docs.aws.amazon.com/powershell/latest/reference/index.html?page=AWS_Resource_Groups_Tagging_API_cmdlets.html&tocid=AWS_Resource_Groups_Tagging_API_cmdlets
.EXAMPLE
    Invoke-AwsEasyTag -tagkey mytag -region $region -tagvalue myvalue -addtag
    Invoke-AwsEasyTag -tagkey mytag -region $region -removetag
    Invoke-AwsEasyTag -tagkey mytag -region $region -tagvalue myvalue -updatetag -newtagvalue mynewvalue
    Invoke-AwsEasyTag $arn ("$arn1",""$arn2") -tagkey mytag -region $region -tagvalue myvalue -addtag
#>

function Invoke-AwsEasyTag {
  param(
    [string]$region = (Get-EC2InstanceMetadata -Category Region | Select-Object -ExpandProperty SystemName),
    [string]$tagkey,
    [string]$tagvalue,
    [string]$newtagvalue,
    [switch]$addtag,
    [switch]$updatetag,
    [switch]$removetag,
    [switch]$showallresources,
    [switch]$showmissing,
    [switch]$showtagged,
    [string]$arn
  )

  process{
    # GET resources
    $allresources = Get-RGTResource -Region $region
    Write-Warning "Found $(($allresources).count) AWS resources."
    if(($addtag -and $updatetag) -or ($removetag -and $updatetag) -or ($removetag -and $addtag) ){
      Write-Warning "You can't more than one statement add/remove/update."
      break
    }
    elseif($tagkey -and -not $tagvalue -and -not $arn){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "not-allowed"
      Write-Warning "Resources using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region
      Write-Warning "Found $(($allresources).count - ($resources).count) resources are missing tag:$tagkey"
      Write-Warning "Show resources missing tag:$tagkey using -showmissing."
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
      if($showmissing){
        $missing = $allresources | Get-AwsEasyTags | Where-Object {-not $_.$tagkey}
        $missing | Select-Object ResourceARN,$tagkey | Sort-Object -descending $tagkey
        Write-Warning "Resources missing $tagkey tag $($missing.count)"
      }
      if($showtagged){
        $onlytagged = $resources | Get-AwsEasyTags | Where-Object {$_.$tagkey}
        $onlytagged | Select-Object $tagkey,ResourceARN,Name | Sort-Object $tagkey,ResourceARN -descending
        Write-Warning "Resources tagged with $tagkey tag $($onlytagged.count)"
      }
    }
    elseif($tagkey -and $tagvalue -and -not $updatetag -and -not $addtag -and -not $arn){
      # resources behind a tag
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "-not-allowed"
      Write-Warning "Resources using $($tagkey):$($tagvalue)."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region | Get-AwsEasyTags | Where-Object { $_."$tagkey" -eq "$tagvalue" }
      $resources | Select-Object $tagkey,ResourceARN,Name | Sort-Object $tagkey,ResourceARN -descending
      Write-Warning "Found $(($resources).count) resources with $($tagkey):$($tagvalue)."
    }
    elseif($tagkey -and $tagvalue -and $updatetag -and -not $arn){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Resources using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    elseif($tagkey -and $tagvalue -and $addtag -and -not $arn){
      # required for add
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Getting resources..."
      $resources = Get-RGTResource -ResourceType $resourcetype -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    elseif(-not $addtag -and $tagkey -and $tagvalue -and -not $arn){
      # required for delete/update
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Resources using key:$tagkey value:$tagvalue..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey"; Values="$tagvalue" } -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey"
      $tagged
    }
    elseif($arn){
      foreach($a in $arn){
        Write-Warning "Using $a..."
      }
    }
    else{
      $cando = "not-allowed"
      Write-Warning "Getting resources..."
      $resources = Get-RGTResource -Region $region | Get-AwsEasyTags
      Write-Warning "Total resources found $(($resources).count)"
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
        $r.ResourceARN | Add-RGTResourceTag -Tag @{ "$tagkey"="$newtagvalue" } -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($arn -and $updatetag -and $tagkey -and $newtagvalue){
      foreach($a in $arn){
        Write-Warning "Tagging $a with key $tagkey value $newtagvalue..."
        $a | Add-RGTResourceTag -Tag @{ "$tagkey"="$newtagvalue" } -Force -Region $region -Verbose
      }
    }
    elseif($arn -and $updatetag -and $tagkey -and -not $newtagvalue){
      Write-Warning "You need -newtagvalue myNewTagValueHere"
      break
    }
    elseif($updatetag -and $cando -eq "not-allowed"){
      Write-Warning "Command -updatetag requires -tagvalue -tagkey"
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
    elseif($arn -and $addtag -and $tagkey){
      foreach($a in $arn){
        Write-Warning "Tagging $a with key $tagkey value $tagvalue..."
        $a | Add-RGTResourceTag -Tag @{ "$tagkey"="$tagvalue" } -Force -Region $region -Verbose
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

    if($showallresources){
      $resources.ResourceARN
    }
  }
}

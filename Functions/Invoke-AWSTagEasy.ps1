# http://docs.aws.amazon.com/powershell/latest/reference/index.html?page=AWS_Resource_Groups_Tagging_API_cmdlets.html&tocid=AWS_Resource_Groups_Tagging_API_cmdlets

function Invoke-AWSTagEasy {
  param(
    [string]$region = (Get-EC2InstanceMetadata -Category Region | Select -ExpandProperty SystemName),
    [string]$tagkey,
    [string]$tagvalue,
    [switch]$addtag,
    [switch]$removetag,
    [switch]$showresources
  )

  process{
    # GET resources
    if($tagkey -and -not $tagvalue){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "not-allowed"
      Write-Warning "Using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region
    }
    elseif($tagkey -and $tagvalue -and $addtag){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Using key:$tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region
    }
    elseif($tagkey -and $tagvalue -and -not $addtag){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      $cando = "allowed"
      Write-Warning "Using key:$tagkey value:$tagvalue..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey"; Values="$tagvalue" } -Region $region
    }
    else{
      $tagged = Get-RGTTagValue -Region $region
      $cando = "not-allowed"
      Write-Warning "Getting all resources..."
      $resources = Get-RGTResource -Region $region
    }

    # ADD/UPDATE tags
    if($addtag -and $cando -eq "allowed"){
      if($tagkey -eq "Name"){
        Write-Warning "Don't play with fire. You cannot change Tag.Name as is the default aws tag."
        break
      }
      foreach($r in $resources){
        Write-Warning "Adding/Editting tag:$tagkey value:$tagvalue on $(($r).ResourceARN)"
        $r.ResourceARN | Add-RGTResourceTag -Tag @{ "$tagkey"="$tagvalue" } -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($addtag -and $cando -eq "not-allowed"){
      Write-Warning "Command -addtag requires -tagvalue -tagkey"
      break
    }

    # REMOVE tags
    if($removetag -and $cando -eq "allowed"){
      if($tagkey -eq "Name"){
        Write-Warning "Don't play with fire. You cannot change Tag.Name as is the default aws tag."
        break
      }
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

    Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey.value"
    $tagged
    if($showresources){
      $resources.ResourceARN
    }
  }
}

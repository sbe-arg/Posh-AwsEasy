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
      $cando = "not-allowed"
      Write-Warning "Using key $tagkey..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey" } -Region $region
    }
    elseif($tagkey -and $tagvalue){
      $cando = "allowed"
      Write-Warning "Using key $tagkey value $tagvalue..."
      $resources = Get-RGTResource -TagFilter @{ Key="$tagkey"; Values="$tagvalue" } -Region $region
    }
    else{
      $cando = "not-allowed"
      Write-Warning "Getting all resources..."
      $resources = Get-RGTResource -Region $region
    }

    # ADD/UPDATE tags
    if($addtag -and $cando -eq "allowed"){
      foreach($r in $resources){
        $r.ResourceARN | Add-RGTResourceTag -Tag @{ Key="$tagkey"; Values="$tagvalue" } -Force -Region $region -Verbose
        Start-Sleep -Seconds 1
      }
    }
    elseif($addtag -and $cando -eq "not-allowed"){
      Write-Warning "Command -addtag requires -tagvalue -tagkey"
      break
    }

    # REMOVE tags
    if($removetag -and $cando -eq "allowed"){
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

    if($tagkey){
      $tagged = Get-RGTTagValue -Key $tagkey -Region $region
      Write-Warning "Total resources found $(($resources).count) where found $(($tagged).count) $tagkey.value"
      $tagged
    }
    if($showresources){
      $resources.ResourceARN
    }
  }
}

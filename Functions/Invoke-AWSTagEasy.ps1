# http://docs.aws.amazon.com/powershell/latest/reference/index.html?page=AWS_Resource_Groups_Tagging_API_cmdlets.html&tocid=AWS_Resource_Groups_Tagging_API_cmdlets

# examples
<# 

old... $tags = '@{ "tagged-by"="powershell-tag-editor"; "portfolio"="fweb" }'

$tags = @'
tagged-by = powershell-tag-editor
portfolio = fweb
'@

#>

function Invoke-AWSTagEasy {
    param(
        [Parameter(Mandatory=$true)]
        [string]$region = (Get-EC2InstanceMetadata -Category Region | Select -ExpandProperty SystemName),

        [string]$tags,

        [string]$filterkey,
        [string]$filtervalue,

        [switch]$addtag,
        [switch]$removetag
    )

    process{

        $tagsresource = ConvertFrom-StringData -StringData $tags

        if($filtervalue -and -not $filterkey){
            Write-Warning "Can't use filtervalue without filterkey"
            break
        }

        if($filterkey -and -not $filtervalue){
            Write-Warning "Using key $filterkey"
            $resources = Get-RGTResource -TagFilter @{ Key="$filterkey" } -Region $region
        }
        elseif($filterkey -and $filtervalue){
            Write-Warning "Using key $filterkey value $filtervalue"
            $resources = Get-RGTResource -TagFilter @{ Key="$filterkey"; Values=@("$filtervalue") } -Region $region
        }
        else{
            $resources = Get-RGTResource -Region $region
        }
        

        # ADD/UPDATE tags
        if($addtag){
          foreach($r in $resources){
                $r.ResourceARN | Add-RGTResourceTag -Tag $tagsresource -Force -Region $region -Verbose
                Start-Sleep -Seconds 1
            }
        }

        # REMOVE tags
        if($removetag){
        foreach($r in $resources){
               $r.ResourceARN | Remove-RGTResourceTag -TagKey @($tagsresource.keys) -Force -Region $region
               Start-Sleep -Seconds 1
            }
        }

        Write-Warning "Total resources found $(($resources).count)"
        Write-Warning "Checking tagkeys... $($tagsresource.keys)"
        foreach($tkey in $tagsresource.keys){
            $tagged = Get-RGTTagValue -Key $tkey -Region $region
            Write-Warning "TagKey $tkey TagValues found: $(($tagged).count)"
            $tagged
        }
        
        $continue = Read-Host "Show resources? [y/n]"
        if($continue -eq 'y'){
            $resources.ResourceARN
        }

    }
}
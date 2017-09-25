# create full stack from single command
# NOTES: atm is for port 80 ingress (world) to server instance port XXXXX... no 443 yet

<#

  $userdata = '{
    $env:computername
  }' # we need this for aditional ec2 config

  $policyjson = '{
  }' # put your verified json here

#>

function New-EasyAwsStack {
  param(
    [Parameter(Mandatory=$true)]
    [string]$serverclass, # name your build

    [string]$url, # r53 dns desired record

    [string]$ami = "WINDOWS_2016_BASE", # make sure u know the naming here

    [string]$instancetype = "t2.micro",

    [string]$hostedzonename, # used for: $url.$hostedzonename dnsrecord

    [Parameter(Mandatory=$true)]
    [string]$vpcfilter, # use vpc name or vpcid

    [string]$instanceport = "80", # port that elb will redirect and allow in ec2 from

    [string]$worldport = "80", # any port for elb external access

    [Parameter(Mandatory=$true)]
    [string]$tagkey,
    [Parameter(Mandatory=$true)]
    [string]$tagvalue,

    [string]$userdata,

    [string]$policyjson
  )
  process{

    # TODO verify json integrity for policy

    # LOGS
      if(!(test-path c:\powershell-logs)){
        new-item -path c:\powershell-logs -itemtype directory
      }
      $logfile = 'c:\powershell-logs\output-log-CreateAStackFromPS.txt'
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) Started process for stack $serverclass." | out-file -append -encoding ascii $logfile

    # REGION
      $region = Get-EC2InstanceMetadata -Category Region | Select -ExpandProperty SystemName
      if($null -eq $region){
        $region = Read-Host "Enter Region"
      }
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) You are in region $region." | out-file -append -encoding ascii $logfile

    # VPC
      $vpcs = Get-EC2Vpc -Region $region
      $getvpcs = foreach($vpc in $vpcs){
          foreach($t in $vpc.tags){
              $vpc | Add-Member -MemberType NoteProperty -Name $t.Key -Value $t.Value -ErrorAction SilentlyContinue -Force
          }
          $vpc | select *
      }
      $vpc = $getvpcs | where {$_.Name -like "*$vpcfilter*" -or $_.VpcId -eq $vpcfilter}
      $vpc
      if($($vpc.count) -gt '1'){
        Write-Warning "Found $($vpc.count) VPCs."
        break
      }
      if($null -eq $vpc){
        Write-Warning "No VPC found."
        break
      }
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) Identified vpc $($vpc.VpcId)." | out-file -append -encoding ascii $logfile

    # continue
      Write-Warning "Region set to $region"
      $serverclass_check = $serverclass.Length
      if($serverclass_check -gt '28'){
        # 28 ensure all other commands fill requirements
        Write-Warning "Serverclass $serverclass is too long. try less than 28 char."
        break
      }
      Write-Warning "Name set to $serverclass"
      Write-Warning "AMI set to $ami"
      Write-Warning "Instance Type set to $instancetype"
      if($url -and $hostedzonename){
        Write-Warning "DnsNameset to $url to be added to $hostedzonename zone"
      }
      $continue = Read-Host "Continue? [y/n]"
      if($continue -ne 'y'){
        break
      }

    # AMI
      $ami_data = Get-EC2ImageByName -Name $ami -Region $region # use the latest ami for select os
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) Locked ami $($ami_data.ImageId) $($ami_data.Name)." | out-file -append -encoding ascii $logfile

    # IAM
      $iamrole = "iam-role-" + $serverclass # required by launch config
      $iam_doco = '"Principal": { "Service": "ec2.amazonaws.com" }'
      New-IAMRole -RoleName $iamrole -Description $serverclass -AssumeRolePolicyDocument $iam_doco -Region $region
      $iampolicyname = "iam-policy-" + $serverclass
      $iampolicy = Get-IAMAttachedRolePolicies -RoleName $iamrole -Region $region | where {$_.PolicyName -eq $iampolicyname}
      if($null -eq $iampolicy){
        # create
        Write-IAMRolePolicy -RoleName $iamrole -PolicyName $iampolicyname -PolicyDocument $policyjson -PassThru
        # New-IAMPolicy -PolicyName $iampolicyname -Description "Created by powershell" -PolicyDocument $policyjson -Region $region
      }
      else{
        # update
        New-IAMPolicyVersion -PolicyArn $iampolicy.PolicyArn -PolicyDocument $policyjson -Region $region
      }
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) Created IAM role w/ policy." | out-file -append -encoding ascii $logfile
      # ^ based on http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage_modify.html#roles-managingrole-editing-cli


    # AZs
      $availability_zones = Get-EC2AvailabilityZone -Region $region

    # SECURITY GROUP
      $sec_group_name_elb = "sec-group-elb-" + $serverclass
      $sec_group_name_ec2 = "sec-group-ec2-" + $serverclass
      # configure as many ingress rules u need using $ip1,$ip2,etc add them in Grant-EC2SecurityGroupIngress @()
      $ip1_elb  = new-object Amazon.EC2.Model.IpPermission
      $ip1_elb.IpProtocol = "tcp"
      $ip1_elb.FromPort = $worldport
      $ip1_elb.ToPort = $instanceport
      $ip1_elb.IpRanges.Add("0.0.0.0/0")

      $ip1_ec2 = new-object Amazon.EC2.Model.IpPermission
      $ip1_ec2.IpProtocol = "tcp"
      $ip1_ec2.FromPort = $instanceport
      $ip1_ec2.ToPort = $instanceport
      $ip1_ec2.IpRanges.Add("0.0.0.0/0")

      $sec_group_elb = Get-EC2SecurityGroup -Region $region | where {$_.GroupName -eq $sec_group_name_elb}
      $sec_group_ec2 = Get-EC2SecurityGroup -Region $region | where {$_.GroupName -eq $sec_group_name_ec2}
      if(!($sec_group_elb)){
        New-EC2SecurityGroup -Description $serverclass -GroupName $sec_group_name_elb -VpcId $vpc.VpcId -Region $region
        # get the sec group again in case it was created
        $sec_group_elb = Get-EC2SecurityGroup -Region $region | where {$_.GroupName -eq $sec_group_name_elb}
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $sec_group_name_elb created." | out-file -append -encoding ascii $logfile
      }
      if(!($sec_group_ec2)){
        New-EC2SecurityGroup -Description $serverclass -GroupName $sec_group_name_ec2 -VpcId $vpc.VpcId -Region $region
        # get the sec group again in case it was created
        $sec_group_ec2 = Get-EC2SecurityGroup -Region $region | where {$_.GroupName -eq $sec_group_name_ec2}
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $sec_group_name_ec2 created." | out-file -append -encoding ascii $logfile
      }
      if($null -ne $sec_group_elb){
        Grant-EC2SecurityGroupIngress -GroupId $sec_group_elb.GroupId -IpPermission @( $ip1_elb ) -Region $region
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $($sec_group_elb.GroupName) permissions granted." | out-file -append -encoding ascii $logfile
      }
      if($null -ne $sec_group_ec2){
        Grant-EC2SecurityGroupIngress -GroupId $sec_group_ec2.GroupId -IpPermission @( $ip1_ec2 ) -Region $region
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $($sec_group_ec2.GroupName) permissions granted." | out-file -append -encoding ascii $logfile
      }

    Start-Sleep -s 5

    # SUBNET
      $subnet = Get-EC2Subnet -Region $region | where {$_.VpcId -like $vpc.VpcId -and $_.DefaultForAz -eq 'True'}

    # ELB
      $elb_name = "elb-" + $serverclass
      $httpListener = New-Object Amazon.ElasticLoadBalancing.Model.Listener
      $httpListener.Protocol = "http"
      $httpListener.LoadBalancerPort = $worldport
      $httpListener.InstanceProtocol = "http"
      $httpListener.InstancePort = $instanceport
      New-ELBLoadBalancer -LoadBalancerName $elb_name -AvailabilityZone @( $($availability_zones).ZoneName ) -Subnet $subnet.AvailabilityZone -SecurityGroup $sec_group_elb.GroupId -Listener $httpListener -Region $region
      $elb_data = Get-ELBLoadBalancer -LoadBalancerName $elb_name
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $elb_name created with AZ $($subnet.AvailabilityZone)." | out-file -append -encoding ascii $logfile

    Start-Sleep -s 10

    # LAUNCH CONFIGURATION
      $lconfig_name = "lconfig-" + $serverclass
      $lconfig_instance_type = $instancetype
      New-ASLaunchConfiguration -LaunchConfigurationName $lconfig_name -ImageId $ami_data.ImageId -UserData $userdata -SecurityGroup $sec_group_elb.GroupId -InstanceType $lconfig_instance_type -IamInstanceProfile $iamrole -InstanceMonitoring_Enabled $true -Region $region
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $lconfig_name created." | out-file -append -encoding ascii $logfile

    # ASG
      $asg_tag1 = New-Object Amazon.AutoScaling.Model.Tag
      $asg_tag1.Key = "serverclass"
      $asg_tag1.Value = "$serverclass"
      $asg_tag2 = New-Object Amazon.AutoScaling.Model.Tag
      $asg_tag2.Key = "created-by"
      $asg_tag2.Value = "powershell.$env:USERNAME.$env:COMPUTERNAME"
      $asg_tag3 = New-Object Amazon.AutoScaling.Model.Tag
      $asg_tag3.Key = $tagkey
      $asg_tag3.Value =$tagvalue

      $asg_tags = ($asg_tag1,$asg_tag2,$asg_tag3)
      $asg_name = "asg-" + $serverclass
      New-ASAutoScalingGroup -AutoScalingGroupName $asg_name -LoadBalancerName $elb_name -LaunchConfigurationName $lconfig_name -AvailabilityZone @( $($availability_zones).ZoneName ) -Tag @($asg_tags) -MinSize 1 -MaxSize 1 -Region $region
      Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $asg_name created." | out-file -append -encoding ascii $logfile
      $asg = Get-ASAutoScalingGroup -AutoScalingGroupName $asg_name -Region $region
      if($asg){
        Update-ASAutoScalingGroup -AutoScalingGroupName $asg.Name -MaxSize 1 -MinSize 1 -HealthCheckType EC2 -HealthCheckGracePeriod 30 -Region $region
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) $asg_name updated sizes and healthcheck." | out-file -append -encoding ascii $logfile
      }
      else{
        Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) ERROR $asg_name not found." | out-file -append -encoding ascii $logfile
      }

    sleep 10

    # R53
    if($url -and $hostedzonename){
      $HostedZoneId = Get-R53HostedZones | where {$_.Name -eq $hostedzonename}
      $elb_data.DNSName
      $change = New-Object Amazon.Route53.Model.Change
      $change.Action = "CREATE"
      $change.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
      $change.ResourceRecordSet.Name = $url
      $change.ResourceRecordSet.Type = "A"
      $change.ResourceRecordSet.AliasTarget = New-Object Amazon.Route53.Model.AliasTarget
      $change.ResourceRecordSet.AliasTarget.HostedZoneId = $HostedZoneId.Id
      $change.ResourceRecordSet.AliasTarget.DNSName = $elb_data.DNSName
      $change.ResourceRecordSet.AliasTarget.EvaluateTargetHealth = $false
      $params = @{
        HostedZoneId=$($HostedZoneId.Id)
      	ChangeBatch_Comment="This change batch creates an alias resource record set, for $serverclass, pointing to $($elb_data.DNSName)"
      	ChangeBatch_Change=$change
      }
      Edit-R53ResourceRecordSet @params
      Write-Output "$(Get-Date -Format  dd/MMM/yyyy:HH:mm:ss) $url added to $hostedzonename with endpoint $($elb_data.DNSName)." | out-file -append -encoding ascii $logfile
    }

    Write-Output "$(Get-Date -Format dd/MMM/yyyy:HH:mm:ss) Finished." | out-file -append -encoding ascii $logfile
  } # close process
} # close function

<#
# TODO Cleanup?...
  function Get-EC2TagsMagic {
      param(
          [Parameter(ValueFromPipeline=$true)][PsObject[]]$InputObject,
          [string[]]$ExpandProperty=@("Tags")
      )
      process {
          foreach ($o in $InputObject) {
              foreach ($e in $ExpandProperty) {
                  if ($o | Get-Member $e) {
                      foreach($t in $o.$e) {
                          $o | Add-Member -MemberType NoteProperty -Name $t.Key -Value $t.Value -ErrorAction SilentlyContinue -Force
                      }
                  }
                  $o
              }
          }
      }
  }

  Get-EC2Instance -Region $region | Get-EC2TagsMagic | where {$_.serverclass -like $serverclass} -Verbose # TODO add stop
  Get-EC2SecurityGroup -Region $region | where {$_.GroupName -like "*$serverclass*" | Remove-EC2SecurityGroup -Region $region}

#>

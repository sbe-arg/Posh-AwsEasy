<#
.SYNOPSIS
    Get rid of all the stuff created by New-EasyAwsStack.
.DESCRIPTION
    N/A.
.EXAMPLE
    New-AwsEasyStack -serverclass mystackname -region where?
#>

function Remove-AwsEasyStack {
  [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
  param(
    [Parameter(Mandatory=$true)]
    [string]$serverclass, # name your build

    [Parameter(Mandatory=$true)]
    [string]$region
  )
  process{
    #asg
      Write-Output "Downscale asg-$serverclass to 0, terminating instances."
      Update-ASAutoScalingGroup -AutoScalingGroupName asg-$serverclass -MaxSize 0 -MinSize 0 -DesiredCapacity 0 -PassThru -Force -Region $region
      start-sleep -s 180
      Remove-ASAutoScalingGroup -AutoScalingGroupName asg-$serverclass -PassThru -Force -Region $region
      start-sleep -s 10
    #elb
      Get-ELBLoadBalancer -Region $region | Where-Object {$_.LoadbalancerName -like "*$serverclass"} | Remove-ELBLoadBalancer -PassThru -Force -Region $region
      start-sleep -s 10
    #launch config
      Remove-ASLaunchConfiguration -LaunchConfigurationName lconfig-$serverclass -PassThru -Force -Region $region
      start-sleep -s 20
    #iam SSM unregister
      Unregister-IAMRolePolicy -RoleName iam-role-$serverclass -PolicyArn arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM -PassThru -Force -Region $region
      start-sleep -s 5
    #iam instance profile
      Remove-IAMRoleFromInstanceProfile -InstanceProfileName iam-profile-$serverclass -RoleName iam-role-$serverclass -Force -PassThru -Region $region
      start-sleep -s 5
    #iam policy
      Remove-IAMRolePolicy -RoleName iam-role-$serverclass -PolicyName iam-policy-$serverclass -PassThru -Force -Region $region
      start-sleep -s 5
    #iam role
      Remove-IAMRole -RoleName iam-role-$serverclass -Force -PassThru -Region $region
      start-sleep -s 5
    #instance profile
      Remove-IAMInstanceProfile -InstanceProfileName iam-profile-$serverclass -PassThru -Force -Region $region
      start-sleep -s 20
    #securitygroups
      Get-EC2SecurityGroup -Region $region | Where-Object {$_.GroupName -like "*$serverclass"} | Remove-EC2SecurityGroup -PassThru -Force -Region $region
  } # close process
} # close function

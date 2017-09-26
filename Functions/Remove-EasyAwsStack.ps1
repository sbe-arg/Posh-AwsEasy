function Remove-EasyAwsStack {
  param(
    [Parameter(Mandatory=$true)]
    [string]$serverclass, # name your build
    [Parameter(Mandatory=$true)]
    [string]$region
  )
  process{
    #elb
      Get-ELBLoadBalancer -Region $region | where {$_.LoadbalancerName -like "*$serverclass"} | Remove-ELBLoadBalancer -PassThru -Force -Region $region
    start-sleep -s 5
    #iam policy
      Remove-IAMRolePolicy -RoleName iam-role-$serverclass -PolicyName iam-policy-$serverclass -PassThru -Force -Region $region
    #iam role
      Remove-IAMRole -RoleName iam-role-$serverclass -Force -Region $region
    #instance profile
      Remove-IAMInstanceProfile -InstanceProfileName iam-profile-$serverclass -PassThru -Force -Region $region
    start-sleep -s 10
    #ec2
      Get-EC2Instance -Region $region | select -ExpandProperty instances | Get-AwsEasyTags | where {$_.serverclass -like $serverclass} | Remove-EC2Instance -Force -Region $region
    start-sleep -s 20
    #asg
      Remove-ASAutoScalingGroup -AutoScalingGroupName asg-$serverclass -PassThru -Force -Region $region
    start-sleep -s 10
    #launch config
      Remove-ASLaunchConfiguration -LaunchConfigurationName lconfig-$serverclass -PassThru -Region $region
    start-sleep -s 20
    #securitygroups
      Get-EC2SecurityGroup -Region $region | where {$_.GroupName -like "*$serverclass"} | Remove-EC2SecurityGroup -PassThru -Force -Region $region
  } # close process
} # close function

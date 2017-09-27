function Remove-EasyAwsStack {
  param(
    [Parameter(Mandatory=$true)]
    [string]$serverclass, # name your build
    [Parameter(Mandatory=$true)]
    [string]$region
  )
  process{
    #asg
      Update-ASAutoScalingGroup -AutoScalingGroupName asg-$serverclass -MaxSize 0 -MinSize 0 -DesiredCapacity 0 -Force -Region $region
      start-sleep -s 180
      Remove-ASAutoScalingGroup -AutoScalingGroupName asg-$serverclass -PassThru -Force -Region $region
      start-sleep -s 10
    #elb
      Get-ELBLoadBalancer -Region $region | where {$_.LoadbalancerName -like "*$serverclass"} | Remove-ELBLoadBalancer -PassThru -Force -Region $region
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
      start-sleep -s 5
    #securitygroups
      Get-EC2SecurityGroup -Region $region | where {$_.GroupName -like "*$serverclass"} | Remove-EC2SecurityGroup -PassThru -Force -Region $region
  } # close process
} # close function

# Posh-AwsEasy
Hand commands for AWS management.

# To test/debug:
Download module -> run Posh-AwsEasy.sandbox.ps1 to load.

### Step One: Install psget
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/psget/psget/master/GetPsGet.ps1") | iex
```


### Step Two: Install Posh-AwsEasy
```powershell
psget\Install-Module -ModuleUrl https://github.com/sbe-arg/Posh-AwsEasy/archive/master.zip
```

## Upgrading
From time-to-time *Posh-AwsEasy* will be updated to include new features.
To update *Posh-AwsEasy*, execute the following:
```powershell
psget\Install-Module -ModuleUrl https://github.com/sbe-arg/Posh-AwsEasy/archive/master.zip -Update
```

```powershell
# examples go here
```


# Open Source:
I have no affiliation with AWS, take a copy and do whatever :)

# Recomended module:
*CloudRemoting* https://github.com/murati-hu/CloudRemoting

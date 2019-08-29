# Export-PendingAccounts
This script will export the list of Pending Accounts from CyberArk EPV to a CSV file. The export process can also be easily configured to send the report to additional locations like a database or API.

The script requires a CyberArk user stored in a cred file. 

## Install Instructions

#### Download Script
1. Download [Export-PendingAccounts.ps1](https://raw.githubusercontent.com/T3hUb3rK1tten/Export-PendingAccounts/master/Export-PendingAccounts.ps1) and store this in a permanent location
2. We'll be adding some additional files in the next steps, the folder structure will look like this when it's done:
![image](https://user-images.githubusercontent.com/566438/62514192-f110b380-b80d-11e9-8ef3-f77497ae5ce5.png)

### PoShPACLI
First, we need to install [PoShPACLI](https://github.com/pspete/PoShPACLI/) to the machine's PowerShell Modules. This needs to be done once per machine.

#### Automatic Install
This will install PoShPACLI from [PowerShell Gallery](https://www.powershellgallery.com/packages/PoShPACLI/):
1. Run `Install-Module -Name PoShPACLI -Scope AllUsers` in PowerShell as admin
2. Run `Import-Module PoShPACLI` in PowerShell and verify there are no errors

#### Manual Install
1. Download the [PoShPACLI zip](https://github.com/pspete/PoShPACLI/archive/master.zip)
2. Run `$env:ProgramFiles\PowerShell\Modules` in PowerShell
3. Extract the PoShPACLI folder from that zip to the above directory
4. Run `Import-Module PoShPACLI` in PowerShell and verify there are no errors

### PACLI
We need the latest PACLI executable:
1. Log in to the [CyberArk Support Vault](https://support.cyberark.com) (you may need to copy/paste this link to a new tab)
2. Navigate to the `CyberArk PAS Solution` safe and choose the folder for the latest version 
3. Under `PAS Components\APIs CD Image` you'll find `PACLI-Rls-[version].zip`
4. Extract the "PACLI" folder in the zip to the same location as the script (you can also configure a path in the script)

### Vault User Setup
We need a credential file for the user the script will use:
1. Create a new CyberArk authentication user, i.e. `ExportPendingAccounts`  
The password for this user will be changed automatically whenever the script is run (you can disable this by setting `$AutoChangePassword = $false`)
2. Give the new user "List files" or "List accounts" permission on the Safe PasswordManager_Pending  
**Do not give this user additional permissions or add it to Vault Admins!**
3. If running on a server with a CyberArk component installed, you can use the built in `CreateCredFile.exe`  
If running on a different machine, you will need to copy the `CreateCredFile.exe` and its dependent files over from an existing CyberArk component install
4. Run `CreateCredFile.exe user.ini Password`
5. Provide the new username and password, then hit enter to all the other questions
6. Store the `user.ini` file in the same location as the script (you can also configure a path in the script)

### Script Setup
Now you can configure and run the script:
1. Edit `Export-PendingAccounts.ps1`
1. Provide your Vault IP/hostname and if necessary specify the path to the PACLI folder and cred file
4. Test the script by running in PowerShell `.\Export-PendingAccounts.ps1`
5. If you encounter errors about not being able to start PACLI, try running `Stop-PVPacli` to make sure old PACLI processes are stopped
6. The script should create a `PendingAccounts.csv` file in the current directory when finished

### Automation Setup
Once you've verified the script performs like you want it to, just schedule the script from Task Manager to run as often as you like:
- Program: `powershell`
- Arguments: `-File Export-PendingAccounts.ps1 -ExecutionPolicy Bypass`
- Start in: The location of the script

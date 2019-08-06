###########################################################
#
# Export-PendingAccounts.ps1
#
# Copyright 2019 Astra West
#
# This script is not officially supported or endorsed by CyberArk, Inc.
#
# Licensed under the MIT License
#
###########################################################

# Change these properties for your Vault install:
$VaultAddress = "vault.example.com"

# Location of cred file to use
$CredFile = "user.ini"

# Location of PACLI executable
$PACLIFolder = "PACLI\Pacli.exe"

# Location of output CSV file
$OutputFile = "PendingAccounts.csv"

# If you use a self-signed cert on the Vault, set this to true
$AllowSelfSignedCertificates = $false

# This will cause PACLI to rotate the password of the account in the cred file automatically
$AutoChangePassword = $true

# Properties to show first in final report columns
# This is so that the output looks similar to the Pending Accounts tab
$ShowFirstProperties = "UserName", "Address", "DiscoveryPlatformType", "Dependencies", "LastPasswordSetDate", "AccountCategory"

# Properties to exclude in final report
# We use this to remove some internal properties not useful in this case
$ExcludeProperties =  "InternalName", "DeletionDate", "DeletionBy", "LastUsedDate", "LastUsedBy",
    "Size", "History", "RetrieveLock", "LockDate", "LockedBy", "FileID", "Draft", "Accessed",
    "LockedByGW", "LockedByUserId", "Safename", "Folder", "user", "vault", "sessionID", "MasterPassFolder"

# End settings

###########################################################

# The below function can be customized to meet your business needs

function SaveResults( $results ) {
    
    # Save the result as a CSV to the $OutputFile configured above
    $results | Export-Csv -Path $OutputFile -NoTypeInformation

}

###########################################################

$ErrorActionPreference = "Stop"

# Get username from cred file
$User = Select-String -Path  $CredFile -Pattern "Username=(\S*)" | % { $_.Matches.Groups[1].Value }

# Helper constants
$PendingSafe = "PasswordManager_Pending"
$Vault = "vault"

# Connect to Vault
Import-Module PoShPACLI
Set-PVConfiguration -ClientPath $PACLIFolder
Start-PVPacli
New-PVVaultDefinition -vault $Vault -address $VaultAddress -preAuthSecuredSession -trustSSC:$AllowSelfSignedCertificates
$token = Connect-PVVault -vault $Vault -user $User -logonFile $CredFile -autoChangePassword:$AutoChangePassword

# Retrieve list of objects in safe
$token | Open-PVSafe -safe $PendingSafe
$files = $token | Get-PVFileList -safe $PendingSafe -folder "Root"

# Remove internal CPM .txt files
$files = $files | Where { $_.Filename -notmatch ".*\.txt$" }

# We use this later to select the properties we want with certain properties first
$SelectProperties = $ShowFirstProperties

# Add file category information to objects
foreach ($file in $files) {
    $categories = $token | Get-PVFileCategory -safe $PendingSafe -folder "Root" -file $file.Filename

    foreach ($category in $categories) {
        # Add the category as a property to the original file object
        $file | Add-Member -NotePropertyName $category.CategoryName -NotePropertyValue $category.CategoryValue

        # If this is the first time we've seen this property, add it here
        # Different objects have different properties (file categories) so we have to check each time
        if ($SelectProperties -notcontains $category.CategoryName) {
            $SelectProperties += $category.CategoryName
        }
    }
}

# Find dependencies and fill in some basic info
foreach ($file in $files | Where { $_.MasterPassName -ne $null }) {
    $masterpass = $files | Where { $_.Filename -eq $file.MasterPassName}

    $PropertiesToCopy = "UserName", "Dependencies", "MachineOSFamily", "OSVersion", "Domain", "OU",
    "LastPasswordSetDate", "LastLogonDate", "AccountExpirationDate", "PasswordNeverExpires", "AccountCategory"

    # Copy property info over if not null
    foreach ($PropertyName in $PropertiesToCopy) {
        $property = $masterpass | select -ExpandProperty $PropertyName
        if ($property -ne $null) {
            $file | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $property
        }
    }
}


# Remove the excluded properties
# We do this last because the user might exclude properties like MasterPassName we need earlier
$files = $files | Select $SelectProperties -ExcludeProperty $ExcludeProperties

$DebugPreference = "silentlycontinue"
$VerbosePreference = "silentlycontinue"

Disconnect-PVVault -vault $Vault -user $User
Stop-PVPacli

# Pass result object to user-customizable function
SaveResults -results $files
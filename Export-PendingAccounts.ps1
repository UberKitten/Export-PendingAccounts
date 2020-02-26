<#
	.SYNOPSIS
	Exports pending accounts from vault into CSV file
	.PARAMETER VaultAddress
	The DNS Name or IP Address of the vault. Required.
	.PARAMETER PACLIPath
	Path to the PACLI executable. Defaults to "PACLI\pacli.exe"
	.PARAMETER CredFilePath
	Path to credentials file created by CyberArk CreateCredFile.exe. Defaults to "user.ini"
	.PARAMETER OutputFile
    Name of CSV file for output. Defaults to "PendingAccounts.csv"
    .PARAMETER AllowSelfSignedCertificates
    Set to $true if vault uses a self signed certificate
    .PARAMETER AuthChangePassword
    If true, password in $credFilePath will be rotated on login. Defaults to true.
	.NOTES
	###########################################################
    #   
    # Export-PendingAccounts.ps1
    #
    # Copyright 2019 Michael West
    #
    # This script is not officially supported or endorsed by CyberArk, Inc.
    #
    # Licensed under the MIT License
    #
    ###########################################################
    Updates by Justin B. Alcorn 2020
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword","")]
Param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$VaultAddress,

    [Parameter(
        Mandatory = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$PACLIPath = "PACLI\Pacli.exe",

    [Parameter(
        Mandatory = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$CredFilePath = "user.ini",

    [Parameter(
        Mandatory = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$OutputFile = "PendingAccounts.csv",

    [Parameter(
        Mandatory = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [boolean]$AllowSelfSignedCertificates = $false,

    [Parameter(
        Mandatory = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [boolean]$AutoChangePassword = $true
)

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

# Resolve relative paths
$PACLIPath = Resolve-Path -LiteralPath $PACLIPath
$CredFilePath = Resolve-Path -LiteralPath $CredFilePath

# Get username from cred file
$User = Select-String -LiteralPath $CredFilePath -Pattern "Username=(\S*)" | % { $_.Matches.Groups[1].Value }

# Helper constants
$PendingSafe = "PasswordManager_Pending"
$Vault = "vault"

# Connect to Vault
Import-Module PoShPACLI
Set-PVConfiguration -ClientPath $PACLIPath
Start-PVPacli
New-PVVaultDefinition -vault $Vault -address $VaultAddress -preAuthSecuredSession -trustSSC:$AllowSelfSignedCertificates
try {
Connect-PVVault -user $User -logonFile $CredFilePath -autoChangePassword:$AutoChangePassword
}
catch {
    Stop-PVPacli
    throw
}

# Retrieve list of objects in safe
Open-PVSafe -safe $PendingSafe
$files = Get-PVFileList -safe $PendingSafe -folder "Root"

# Remove internal CPM .txt files
$files = $files | Where { $_.Filename -notmatch ".*\.txt$" }

# We use this later to select the properties we want with certain properties first
$SelectProperties = $ShowFirstProperties

# Add file category information to objects
foreach ($file in $files) {
    $categories = Get-PVFileCategory -safe $PendingSafe -folder "Root" -file $file.Filename

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

Disconnect-PVVault 
Stop-PVPacli

# Pass result object to user-customizable function
SaveResults -results $files
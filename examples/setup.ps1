<# =============================================================================
.DESCRIPTION
    This script is intended to help configure an environment to use PS.SSL
.NOTES
    General notes
============================================================================= #>

# SET VARIABLS
$moduleUrl = 'https://github.com/johnsarie27/PS.SSL/archive/refs/heads/main.zip'
$moduleFolder = "$HOME\Documents\PowerShell\Modules"

# STEP 1: INSTALL OPENSSL
choco install openssl -y

# STEP 2: DOWNLOAD COMPRESSED MODULE
Invoke-WebRequest -Uri $moduleUrl -OutFile "$HOME\Desktop\PS.SSL.zip"

# STEP 3: EXPAND PS.SSL TO PS 7 MODULES FOLDER
Expand-Archive -Path "$HOME\Desktop\PS.SSL.zip" -DestinationPath $moduleFolder

# STEP 4: GET VERSION AND RENAME MODULE FOLDER
Rename-Item -Path "$moduleFolder\PS.SSL-main" -NewName "PS.SSL"

# STEP 5: UNBLOCK NEW MODULE
Get-ChildItem -Path "$moduleFolder\PS.SSL" -Recurse | Unblock-File

# STEP 6: COPY EXAMPLE FILES TO DESKTOP
Copy-Item -Path "$moduleFolder\PS.SSL\examples" -Destination "$HOME\Desktop\ps.ssl-examples" -Recurse

# STEP 7: CLEANUP ARTIFACTS
Remove-Item -Path "$HOME\Desktop\PS.SSL.zip"

# TEST SCRIPT
code "$HOME\Desktop\ps.ssl-examples\GenerateCSR.ps1"

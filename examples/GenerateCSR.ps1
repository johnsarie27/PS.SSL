<# =============================================================================
.DESCRIPTION
    Create, validate, and complete the CSR process
.NOTES
    General notes
============================================================================= #>

# IMPORT MODULE
Import-Module -Name 'PS.SSL'

# SET DIRECTORY FOR PRIVATE KEY AND CERTIFICATES
$root = "$HOME\Desktop\test\CSR"

# CREATE NEW PRIVATE KEY AND CERTIFICATE SIGNING REQUEST (CSR)
New-CSR -OutputDirectory $root -ConfigFile "$root\example_template.conf"

# VERIFY UNSIGNED CSR ATTRIBUTES
Confirm-CSR -CSR "$root\www.company.com.csr"

# AT THIS POINT THE CSR CAN BE SENT TO A PUBLIC CERTIFICATE AUTHORITY FOR SIGNING
# DO NOT PROCEEED WITH THE BELOW STEPS UNTIL A SIGNED CSR HAS BEEN RETURNED

# VERIFY SIGNED CERTIFICATE
Get-CertificateDetails -Path "$root\digicert\<SIGNED_CSR>.crt"

# VERIFY INTERMEDIATE CERTIFICATE
Get-CertificateDetails -Path "$root\digicert\DigiCertCA.crt"

# VERIFY ROOT CERTIFICATE
Get-CertificateDetails -Path "$root\digicert\TrustedRoot.crt"

# COMPLETE PROCESS BY EXPORTING PFX/P12
$pfxParams = @{
    OutputDirectory = "$root\completed"
    Password        = Read-Host -AsSecureString -Prompt 'Password'
    SignedCSR       = "$root\digicert\<CERTIFICATE>.crt"
    Key             = "$root\<PRIVATE_KEY>.key"
    RootCA          = "$root\digicert\TrustedRoot.crt"
    IntermediateCA  = "$root\digicert\DigiCertCA.crt"
}
Export-PFX @pfxParams

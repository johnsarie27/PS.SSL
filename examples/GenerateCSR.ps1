<# =============================================================================
.SYNOPSIS
    Create, validate, and complete the CSR process
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


# VERIFY SIGNED CERTIFICATE
Confirm-SignedCSR -SignedCSR "$root\digicert\<SIGNED_CSR>.crt"

# COMPLETE PROCESS BY EXPORTING PFX/P12
$pfxParams = @{
    OutputDirectory = "$root\completed"
    SignedCSR       = "$root\digicert\<CERTIFICATE>.crt"
    Key             = "$root\<PRIVATE_KEY>.key"
    RootCA          = "$root\digicert\DigiCertCA.crt"
    IntermediateCA  = "$root\digicert\TrustedRoot.crt"
}
Export-PFX @pfxParams

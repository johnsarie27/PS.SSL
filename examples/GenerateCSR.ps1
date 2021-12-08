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

# CREATE EXAMPLE TEMPLATE IN ROOT
$CSR_Template | Set-Content -Path "$root\template.conf"

# OPEN THE CONFIG FILE AND EDIT THE REQUIRED PROPERTIES
code "$root\template.conf"

# CREATE NEW PRIVATE KEY AND CERTIFICATE SIGNING REQUEST (CSR)
New-CSR -OutputDirectory $root -ConfigFile "$root\template.conf"

# OR -- USE THE FOLLOWING TO CREATE THE CSR
$csrParams = @{
    OutputDirectory = $root
    Country         = 'US'
    State           = 'California'
    Locality        = 'Redlands'
    Organization    = 'Esri'
    #OU              = 'PS'
    CommonName      = 'www.company.com'
    SAN1            = 'company.com'
    SAN2            = 'www.company.org'
    SAN3            = 'company.org'
}
New-CSR @csrParams

# VERIFY UNSIGNED CSR ATTRIBUTES
Confirm-CSR -CSR "$root\www.company.com.csr"

# ==============================================================================
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

# TEST PASSWORD
Get-PfxCertificate -FilePath $pfx -Password (Read-Host -AsSecureString -Prompt 'Password')

# ==============================================================================
# IF YOU RECEIVE A P7B (OR OTHER PKCS7 FORMATTED FILE) CONTAINING THE SIGNED
# CSR AND OTHER INTERMEDIATE/ROOT CERTIFICATES, USE THE CMDLET BELOW TO
# CONVERT IT AND THEN EXPORT THE PFX

# CONVERT PKCS7
ConvertFrom-PKCS7 -Path "$root\<CERTIFICATE>.pem" -OutputDirectory $root

# COMPLETE PROCESS BY EXPORTING PFX/P12
$pfxParams = @{
    OutputDirectory = "$root\completed"
    Password        = Read-Host -AsSecureString -Prompt 'Password'
    SignedCSR       = "$root\digicert\<CERTIFICATE>.crt"
    Key             = "$root\<PRIVATE_KEY>.key"
}
Export-PFX @pfxParams

# TEST PASSWORD
Get-PfxCertificate -FilePath $pfx -Password (Read-Host -AsSecureString -Prompt 'Password')

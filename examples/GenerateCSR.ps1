# ==============================================================================
# Filename: GenerateCSR.ps1
# Version:  0.0.6 | Updated: 2023-10-05
# Author:   Justin Johns
# ==============================================================================

#Requires -Modules PS.SSL

<# =============================================================================
.DESCRIPTION
    Create, validate, and complete the CSR process
.NOTES
    Version History:
    - 0.0.6 - Added self-signed cert example
    - 0.0.5 - (2021-12-18) Previous version
    - 0.0.1 - Initial version
    General notes:
============================================================================= #>

# IMPORT MODULE
Import-Module -Name 'PS.SSL'

#region NEW CSR FROM INPUTS ====================================================
# USE THE FOLLOWING TO CREATE THE CSR
$csrParams = @{
    OutputDirectory = "$HOME\Desktop\test\CSR"
    #Country         = 'US'
    #State           = 'California'
    #Locality        = 'Redlands'
    #Organization    = 'Esri'
    #OU              = 'PS'
    CommonName      = 'www.company.com'
    SAN1            = 'company.com'
    SAN2            = 'www.company.org'
    #SAN3            = 'company.org'
}
New-CSR @csrParams

#endregion =====================================================================


#region NEW CSR FROM TEMPLATE ==================================================
# SET DIRECTORY FOR PRIVATE KEY AND CERTIFICATES
$root = "$HOME\Desktop\test\CSR"

# CREATE EXAMPLE TEMPLATE IN ROOT
$CSR_Template | Set-Content -Path "$root\template.conf"

# OPEN THE CONFIG FILE AND EDIT THE REQUIRED PROPERTIES
code "$root\template.conf"

# CREATE NEW PRIVATE KEY AND CERTIFICATE SIGNING REQUEST (CSR)
New-CSR -OutputDirectory $root -ConfigFile "$root\template.conf"

#endregion =====================================================================


# VERIFY UNSIGNED CSR ATTRIBUTES
Get-CSRData -CSR "$root\www.company.com.csr"


#region GENERATE PFX ===========================================================
# AT THIS POINT THE CSR CAN BE SENT TO A PUBLIC CERTIFICATE AUTHORITY FOR SIGNING
# DO NOT PROCEEED WITH THE BELOW STEPS UNTIL A SIGNED CSR HAS BEEN RETURNED

# VERIFY SIGNED CERTIFICATE
Get-CertificateData -Path "$root\digicert\<SIGNED_CSR>.crt"

# VERIFY INTERMEDIATE CERTIFICATE
Get-CertificateData -Path "$root\digicert\DigiCertCA.crt"

# VERIFY ROOT CERTIFICATE
Get-CertificateData -Path "$root\digicert\TrustedRoot.crt"

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

#endregion =====================================================================


#region CONVERT PKCS7 (P7B) TO CRT =============================================
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

#endregion =====================================================================


# TEST PASSWORD
$pfx = "$root\completed\<FILE_NAME>.pfx"
Get-PfxCertificate -FilePath $pfx -Password (Read-Host -AsSecureString -Prompt 'Password')


#region - SELF-SIGNED ==========================================================
# GENERATE SELF-SIGNED CERTIFICATE
New-SelfSignedCertificate -CommonName 'myCoolDomain.com'

#endregion =====================================================================

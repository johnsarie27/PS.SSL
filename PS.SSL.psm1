# ==============================================================================
# Filename: PS.SSL.psm1
# Updated:  2024-03-08
# Author:   Justin Johns
# ==============================================================================

# CHECK FOR PLATFORM
if ($IsWindows -or ($null -EQ $IsWindows)) {

    # CHECK FOR OPENSSL
    if ($env:Path -notmatch 'openssl') {
        Write-Warning -Message 'Openssl not found in path. Several functions may not work.'
    }
}
if ($IsMacOS -or $IsLinux) {

    # SET PATHS >> $Env:PATH -split ':'
    $path = @('/usr/bin', '/usr/sbin', '/sbin', '/bin')

    # LOOK FOR OPENSSL
    if ((Get-ChildItem -Path $path).Name -notcontains 'openssl') {
        Write-Warning -Message 'Openssl not found in path. Several functions may not work.'
    }
}

# IMPORT ALL FUNCTIONS
# 'Private' is optional and may be absent (no private helpers). Skip missing
# directories rather than letting Get-ChildItem throw on Linux/macOS where the
# wildcard path is evaluated more strictly.
foreach ( $directory in @('Public', 'Private') ) {
    $dirPath = Join-Path -Path $PSScriptRoot -ChildPath $directory
    if (-not (Test-Path -Path $dirPath -PathType Container)) { continue }
    foreach ( $fn in (Get-ChildItem -Path $dirPath -Filter '*.ps1' -File) ) { . $fn.FullName }
}

# VARIABLES
New-Variable -Name 'CSR_Template' -Option ReadOnly -Value @(
    '[req]'
    'distinguished_name = req_distinguished_name'
    'req_extensions = v3_req'
    'default_bits = 4096'
    'default_md = sha256'
    'encrypt_key = no'
    'prompt = no'
    '[req_distinguished_name]'
    'C = #C#'
    'ST = #ST#'
    'L = #L#'
    'O = #O#'
    'OU = #OU#'
    'emailAddress = "#E#"'
    'CN = #CN#'
    '[v3_req]'
    'keyUsage = keyEncipherment, dataEncipherment'
    'extendedKeyUsage = serverAuth'
    'subjectAltName = @alt_names'
    '[alt_names]'
)

# EXPORT MEMBERS
# THESE ARE SPECIFIED IN THE MODULE MANIFEST AND THEREFORE DON'T NEED TO BE LISTED HERE
#Export-ModuleMember -Function *
Export-ModuleMember -Variable 'CSR_Template' -Alias 'New-CSR'
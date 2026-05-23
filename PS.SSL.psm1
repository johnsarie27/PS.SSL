# ==============================================================================
# Filename: PS.SSL.psm1
# Updated:  2024-03-08
# Author:   Justin Johns
# ==============================================================================

# CHECK FOR PLATFORM
if ($IsWindows -or ($null -eq $IsWindows)) {

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

# EXPORT MEMBERS
# THESE ARE SPECIFIED IN THE MODULE MANIFEST AND THEREFORE DON'T NEED TO BE LISTED HERE
#Export-ModuleMember -Function *
Export-ModuleMember -Alias 'New-CSR'
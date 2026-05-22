function ConvertFrom-PKCS7 {
    <#
    .SYNOPSIS
        Convert PKCS7 formatted certificate
    .DESCRIPTION
        Convert PKCS7 formatted certificate to non-PKCS7 format
    .PARAMETER Path
        Path to PKCS7 formatted certificate file
    .PARAMETER OutputDirectory
        Output directory path
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> ConvertFrom-PKCS7 -Path .\myCert.cer -OutputDirectory .\newFolder
        Converts a PKCS7 formatted certificate to non-PKCS7 format with .crt extension
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to PKCS7 formatted certificate file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({
                if (Test-Path -Path $_ -PathType Leaf) {
                    Write-Error -Message "OutputDirectory '$_' exists but is a file, not a directory." -ErrorAction Stop
                }
                $parent = Split-Path -Path $_ -Parent
                if ([string]::IsNullOrEmpty($parent)) { $parent = '.' }
                if (-not (Test-Path -Path $parent -PathType Container)) {
                    Write-Error -Message "Parent of OutputDirectory does not exist: $parent" -ErrorAction Stop
                }
                $true
            })]
        [System.String] $OutputDirectory = "$HOME\Desktop"
    )
    Begin {
        # GET OUTPUT DIRECTORY
        Initialize-OutputDirectory -Path $OutputDirectory

        # SET OUTPUT FILE NAME
        $name = '{0}.crt' -f (Split-Path -Path $Path -LeafBase)
        Write-Verbose -Message ('Set filename to: {0}' -f $name)
    }
    End {
        # VERIFY SIGNED CERTIFICATE
        # openssl.exe pkcs7 -in certnew.p7b -print_certs -out $newFile
        $outFile = Join-Path -Path $OutputDirectory -ChildPath $name
        [System.Void] (Invoke-OpenSsl -ArgumentList @('pkcs7', '-in', $Path, '-print_certs', '-out', $outFile))
    }
}
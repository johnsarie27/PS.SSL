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
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to PKCS7 formatted certificate file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
        [System.String] $OutputDirectory = (Join-Path -Path $HOME -ChildPath 'Desktop')
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

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
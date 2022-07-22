function ConvertFrom-PKCS7 {
    <# =========================================================================
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
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to PKCS7 formatted certificate file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [System.String] $OutputDirectory = "$HOME\Desktop"
    )
    Begin {
        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory
            Write-Verbose -Message ('Created new folder: {0}' -f $OutputDirectory)
        }

        # SET OUTPUT FILE NAME
        $name = '{0}.crt' -f (Split-Path -Path $Path -LeafBase)
        Write-Verbose -Message ('Set filename to: {0}' -f $name)
    }
    End {
        # VERIFY SIGNED CERTIFICATE
        # openssl.exe pkcs7 -in certnew.p7b -print_certs -out $newFile
        $sslParams = @{
            FilePath     = 'openssl' # .exe
            ArgumentList = @(
                'pkcs7'
                '-in {0}' -f $Path
                '-print_certs'
                '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath $name)
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
    }
}
function Export-CertificateData {
    <#
    .SYNOPSIS
        Split a combined PEM bundle into separate certificate, chain, and
        private key files.
    .DESCRIPTION
        Reads a PEM file that contains a private key followed by one or more
        concatenated certificates (typical of a fullchain export) and writes
        the requested portion to a new PEM file in -OutputDirectory.

        The function does not invoke openssl; it scans the input line-by-line
        for the standard PEM begin/end markers and copies the matching block
        verbatim, preserving the original encoding.

        Expected layout of the input PEM:
          -----BEGIN PRIVATE KEY-----   (optional, required for -Data PrivateKey)
          ...
          -----END PRIVATE KEY-----
          -----BEGIN CERTIFICATE-----   (leaf certificate; required for -Data Certificate)
          ...
          -----END CERTIFICATE-----
          -----BEGIN CERTIFICATE-----   (chain certs; required for -Data Chain)
          ...
          -----END CERTIFICATE-----
          ...

        The output filename is fixed per -Data value and is written under
        -OutputDirectory:
          Certificate -> certificate.pem  (first CERTIFICATE block)
          Chain       -> chain.pem        (2nd through 4th CERTIFICATE blocks, concatenated)
          PrivateKey  -> PRIVATE.key      (PRIVATE KEY block)
    .PARAMETER Path
        Path to a PEM file. Must exist and have a .pem extension.
    .PARAMETER OutputDirectory
        Directory the split file will be written into. Created if missing.
        Defaults to the current user's Desktop.
    .PARAMETER Data
        Which portion of the bundle to extract. One of:
          Certificate -- the leaf certificate (first CERTIFICATE block)
          Chain       -- the chain certificates (2nd through 4th CERTIFICATE blocks)
          PrivateKey  -- the unencrypted private key (PRIVATE KEY block)
    .INPUTS
        None. This function does not accept pipeline input.
    .OUTPUTS
        None. The function writes a file to -OutputDirectory as a side effect.
    .EXAMPLE
        PS C:\> Export-CertificateData -Path .\fullchain.pem -Data Certificate -OutputDirectory .\out
        Writes .\out\certificate.pem containing only the leaf certificate from fullchain.pem.
    .EXAMPLE
        PS C:\> Export-CertificateData -Path .\fullchain.pem -Data Chain -OutputDirectory .\out
        Writes .\out\chain.pem containing the intermediate and root certificates
        (up to three) concatenated in the original order.
    .EXAMPLE
        PS C:\> Export-CertificateData -Path .\fullchain.pem -Data PrivateKey -OutputDirectory .\out
        Writes .\out\PRIVATE.key containing only the private key block.
    .NOTES
        Status: Beta
        - Chain extraction is currently capped at the 2nd through 4th
          CERTIFICATE blocks (intermediates plus an optional root). Bundles
          with more than four CERTIFICATE blocks will silently drop the rest.
        - Output filenames are fixed and will overwrite any existing file of
          the same name in -OutputDirectory.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Path to PEM file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Filter '*.pem' })]
        [System.String] $Path,

        [Parameter(Position = 1, HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, Position = 2, HelpMessage = 'Data to export')]
        [ValidateSet('Certificate', 'Chain', 'PrivateKey')]
        [System.String] $Data
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

        # GET OUTPUT DIRECTORY
        Initialize-OutputDirectory -Path $OutputDirectory

        # GET PEM CONTENT
        $pemContent = Get-Content -Path $Path
    }
    End {
        # SET LINE MARKERS
        $beginKeyLineNum = ($pemContent | Select-String -Pattern '-----BEGIN PRIVATE KEY-----').LineNumber
        $endKeyLineNum = ($pemContent | Select-String -Pattern '-----END PRIVATE KEY-----').LineNumber
        $beginCertLineNums = ($pemContent | Select-String -Pattern '-----BEGIN CERTIFICATE-----').LineNumber
        $endCertLineNums = ($pemContent | Select-String -Pattern '-----END CERTIFICATE-----').LineNumber

        # CREATE FILES FOR CERT DATA
        switch ($Data) {
            'Certificate' {
                $exportPath = Join-Path -Path $OutputDirectory -ChildPath 'certificate.pem'
                $pemContent[($beginCertLineNums[0] - 1)..($endCertLineNums[0] - 1)] | Set-Content -Path $exportPath
            }
            'Chain' {
                $exportPath = Join-Path -Path $OutputDirectory -ChildPath 'chain.pem'
                $pemContent[($beginCertLineNums[1] - 1)..($endCertLineNums[1] - 1)] | Set-Content -Path $exportPath
                if ($beginCertLineNums[2]) {
                    $pemContent[($beginCertLineNums[2] - 1)..($endCertLineNums[2] - 1)] | Add-Content -Path $exportPath
                }
                if ($beginCertLineNums[3]) {
                    $pemContent[($beginCertLineNums[3] - 1)..($endCertLineNums[3] - 1)] | Add-Content -Path $exportPath
                }
            }
            'PrivateKey' {
                $exportPath = Join-Path -Path $OutputDirectory -ChildPath 'PRIVATE.key'
                $pemContent[($beginKeyLineNum - 1)..($endKeyLineNum - 1)] | Set-Content -Path $exportPath
            }
        }

        # WRITE PATH
        #Write-Output -InputObject $exportPath
    }
}
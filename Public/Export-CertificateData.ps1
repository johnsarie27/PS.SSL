function Export-CertificateData {
    <# =========================================================================
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .PARAMETER Path
        Path to PEM file
    .PARAMETER OutputDirectory
        Output directory for Certificate Data
    .PARAMETER Data
        Data to export
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Export-CertificateData -Path C:\cert.pem -Data Chain
        Export the certificate chain for SSL certificate
    .NOTES
        Name:     Export-CertificateData
        Author:   Justin Johns
        Version:  0.1.0 | Last Edit: 2022-09-30
        - 0.1.0 - Initial version
        Comments: <Comment(s)>
        General notes:
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Path to PEM file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Filter '*.pem' })]
        [System.String] $Path,

        [Parameter(Position = 1, HelpMessage = 'Output report directory')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, Position = 2, HelpMessage = 'Data to export')]
        [ValidateSet('Certificate', 'Chain', 'PrivateKey')]
        [System.String] $Data
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

        # UPDATE OUTPUT DIRECTORY AND CREATE FOLDER
        #$OutputDirectory = Join-Path -Path $OutputDirectory -ChildPath ([System.IO.Path]::GetRandomFileName().Remove(8, 4))
        #New-Item -Path $OutputDirectory -ItemType Directory | Write-Verbose

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
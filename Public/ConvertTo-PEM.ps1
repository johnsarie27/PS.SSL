function ConvertTo-PEM {
    <#
    .SYNOPSIS
        Convert PFX/P12 file to PEM file
    .DESCRIPTION
        Convert PFX/P12 file to PEM file including private key
    .PARAMETER Path
        Path to PFX file. Accepts the legacy alias -PFX.
    .PARAMETER OutputDirectory
        Path to plain text output directory
    .PARAMETER Password
        Password to PFX file
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> ConvertTo-PEM -Path .\myCert.pfx -OutputDirectory .\newFolder -Password $pw
        Converts myCert.pfx to myCert.pem exposing all certificate details in plain text
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to PFX file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.pfx", "*.p12" })]
        [Alias('PFX')]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, HelpMessage = 'Password to PFX file')]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString] $Password
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

        # VALIDATE PASSWORD
        Get-PfxCertificate -FilePath $Path -Password $Password -ErrorAction Stop | Out-Null

        # GET OUTPUT DIRECTORY
        Initialize-OutputDirectory -Path $OutputDirectory

        # SET OUTPUT FILE NAME
        $name = '{0}.pem' -f (Split-Path -Path $Path -LeafBase)
        Write-Verbose -Message ('Set filename to: {0}' -f $name)
    }
    End {
        # VERIFY SIGNED CERTIFICATE
        # openssl pkcs12 -in <PFX_PATH> -out <FILE.TXT> -nodes -passin env:PSSL_PASSIN
        # PASS THE PASSWORD VIA AN ENVIRONMENT VARIABLE SCOPED TO THE OPENSSL
        # CHILD PROCESS - never on argv, never in the parent session - so it
        # is invisible to peer-process listings, ETW process-start events,
        # and EDR command-line telemetry.
        $outFile = Join-Path -Path $OutputDirectory -ChildPath $name
        $sslParams = @{
            ArgumentList        = @('pkcs12', '-in', $Path, '-out', $outFile, '-nodes', '-passin', 'env:PSSL_PASSIN')
            EnvironmentVariable = @{ PSSL_PASSIN = $Password }
        }
        [System.Void] (Invoke-OpenSsl @sslParams)
    }
}
function Export-PFX {
    <# =========================================================================
    .SYNOPSIS
        Export PFX file
    .DESCRIPTION
        Export PFX file from completed CSR, private key, and certificate trust chain
    .PARAMETER OutputDirectory
        Output directory for new PFX file
    .PARAMETER Password
        Password used to protect exported PFX file
    .PARAMETER Key
        Path to private key file
    .PARAMETER SignedCSR
        Path to CA-signed certificate request
    .PARAMETER RootCA
        Path to root CA public certificate
    .PARAMETER IntermediateCA
        Path to intermediate CA public certificate
    .PARAMETER WindowsCompatible
        Export using PBE-SHA1-3DES algorithm
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Export-PFX -Password $secStr -Key .\key.key - SignedCSR .\cert.crt -RootCA .\root.crt
        Creates and exports PFX file from private key, signed certificate, and root CA
    .NOTES
        General notes
        https://man.openbsd.org/openssl.1
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, HelpMessage = 'Password used to protect exported PFX file')]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString] $Password,

        [Parameter(Mandatory, HelpMessage = 'Path to private key file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.key', '*.pem' })]
        [System.String] $Key,

        [Parameter(Mandatory, HelpMessage = 'Path to CA-signed certificate request')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $SignedCSR,

        [Parameter(HelpMessage = 'Path to root CA public certificate')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $RootCA,

        [Parameter(HelpMessage = 'Path to intermediate CA public certificate')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $IntermediateCA,

        [Parameter(HelpMessage = 'Export using PBE-SHA1-3DES algorithm')]
        [System.Management.Automation.SwitchParameter] $WindowsCompatible
    )
    Begin {
        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) { New-Item -Path $OutputDirectory -ItemType Directory | Out-Null }

        # SET PFX PATH - THIS CAN ALSO BE A ".P12" IF DESIRED
        $pfxPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.pfx' -f (Split-Path -Path $SignedCSR -LeafBase))

        # COMBINE CERTIFICATES IN CHAIN
        if ($PSBoundParameters.ContainsKey('IntermediateCA')) {
            $chain = Join-Path -Path $OutputDirectory -ChildPath 'CAChain.crt'
            Get-Content -Path $IntermediateCA | Set-Content -Path $chain
            Get-Content -Path $RootCA | Add-Content -Path $chain
        }
        elseif ($PSBoundParameters.ContainsKey('RootCA')) {
            $chain = $RootCA
        }

        # CREATE CREDENTIAL OBJECT WITH PASSWORD
        $creds = [System.Management.Automation.PSCredential]::new('UserName', $Password)
    }
    End {
        # SET OPENSSL PARAMETERS
        # openssl pkcs12 -export -out myDomain.com.pfx -inkey myDomain.com.key -in myDomain.com.crt -certfile CertChain.crt
        $sslParams = @{
            FilePath     = 'openssl' # .exe
            ArgumentList = @(
                'pkcs12 -export'
                '-out {0}' -f $pfxPath
                '-inkey {0}' -f $Key
                '-in {0}' -f $SignedCSR
                #'-certfile {0}' -f $chain
                '-passout pass:{0}' -f $creds.GetNetworkCredential().Password
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }

        # ADD CERTIFICATE CHAIN
        if ($chain) { $sslParams.ArgumentList += '-certfile {0}' -f $chain }

        # OUTPUT CERTIFICATE AND KEY USING PBE-SHA1-3DES ALGORITHM
        # THIS IS NEEDED FOR WINDOWS SERVER COMPATIBILITY
        if ($WindowsCompatible) {
            $sslParams['ArgumentList'] += '-certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -nomac'
        }

        # START OPENSSL
        $proc = Start-Process @sslParams

        # RETURN RESULT
        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
        else { Write-Output -InputObject $pfxPath }
    }
}
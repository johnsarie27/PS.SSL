function Export-PFX {
    <#
    .SYNOPSIS
        Export PFX file
    .DESCRIPTION
        Export PFX file from completed CSR, private key, and certificate trust chain
    .PARAMETER OutputDirectory
        Output directory for new PFX file
    .PARAMETER Password
        Password used to protect exported PFX file
    .PARAMETER KeyPath
        Path to private key file. Accepts the legacy alias -Key.
    .PARAMETER SignedCSRPath
        Path to CA-signed certificate request. Accepts the legacy alias -SignedCSR.
    .PARAMETER RootCAPath
        Path to root CA public certificate. Accepts the legacy alias -RootCA.
    .PARAMETER IntermediateCAPath
        Path to intermediate CA public certificate. Accepts the legacy alias -IntermediateCA.
    .PARAMETER WindowsCompatible
        Export using PBE-SHA1-3DES algorithm
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Export-PFX -Password $secStr -KeyPath .\key.key -SignedCSRPath .\cert.crt -RootCAPath .\root.crt
        Creates and exports PFX file from private key, signed certificate, and root CA
    .NOTES
        Status: Stable
        References:
        https://man.openbsd.org/openssl.1
    #>
    [CmdletBinding(DefaultParameterSetName = '__nochain')]
    Param(
        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, HelpMessage = 'Password used to protect exported PFX file')]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString] $Password,

        [Parameter(Mandatory, HelpMessage = 'Path to private key file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.key', '*.pem' })]
        [Alias('Key')]
        [System.String] $KeyPath,

        [Parameter(Mandatory, HelpMessage = 'Path to CA-signed certificate request')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [Alias('SignedCSR')]
        [System.String] $SignedCSRPath,

        [Parameter(Mandatory, ParameterSetName = '__rootonly', HelpMessage = 'Path to root CA public certificate')]
        [Parameter(Mandatory, ParameterSetName = '__fullchain', HelpMessage = 'Path to root CA public certificate')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [Alias('RootCA')]
        [System.String] $RootCAPath,

        [Parameter(Mandatory, ParameterSetName = '__fullchain', HelpMessage = 'Path to intermediate CA public certificate')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [Alias('IntermediateCA')]
        [System.String] $IntermediateCAPath,

        [Parameter(HelpMessage = 'Export using PBE-SHA1-3DES algorithm')]
        [System.Management.Automation.SwitchParameter] $WindowsCompatible
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

        # GET OUTPUT DIRECTORY
        Initialize-OutputDirectory -Path $OutputDirectory

        # SET PFX PATH - THIS CAN ALSO BE A ".P12" IF DESIRED
        $pfxPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.pfx' -f (Split-Path -Path $SignedCSRPath -LeafBase))

        # COMBINE CERTIFICATES IN CHAIN (parameter set guarantees RootCA is present when IntermediateCA is)
        switch ($PSCmdlet.ParameterSetName) {
            '__fullchain' {
                $chain = Join-Path -Path $OutputDirectory -ChildPath 'CAChain.crt'
                Get-Content -Path $IntermediateCAPath | Set-Content -Path $chain
                Get-Content -Path $RootCAPath | Add-Content -Path $chain
            }
            '__rootonly' {
                $chain = $RootCAPath
            }
        }
    }
    End {
        # SET OPENSSL ARGUMENTS
        # openssl pkcs12 -export -out myDomain.com.pfx -inkey myDomain.com.key -in myDomain.com.crt -certfile CertChain.crt
        # PASS THE PFX PASSWORD VIA AN ENVIRONMENT VARIABLE SCOPED TO THE
        # OPENSSL CHILD PROCESS - never on argv, never in the parent session
        # - so it is invisible to peer-process listings, ETW process-start
        # events, and EDR command-line telemetry.
        $opensslArgs = [System.Collections.Generic.List[System.String]]::new()
        $opensslArgs.AddRange([System.String[]] @(
            'pkcs12', '-export',
            '-out', $pfxPath,
            '-inkey', $KeyPath,
            '-in', $SignedCSRPath,
            '-passout', 'env:PSSL_PASSOUT'
        ))

        # ADD CERTIFICATE CHAIN
        if ($chain) { $opensslArgs.AddRange([System.String[]] @('-certfile', $chain)) }

        # OUTPUT CERTIFICATE AND KEY USING PBE-SHA1-3DES ALGORITHM
        # THIS IS NEEDED FOR WINDOWS SERVER COMPATIBILITY
        if ($WindowsCompatible) {
            $opensslArgs.AddRange([System.String[]] @(
                '-certpbe', 'PBE-SHA1-3DES',
                '-keypbe', 'PBE-SHA1-3DES',
                '-nomac'
            ))
        }

        # INVOKE OPENSSL
        $sslParams = @{
            ArgumentList        = $opensslArgs.ToArray()
            EnvironmentVariable = @{ PSSL_PASSOUT = $Password }
        }
        [System.Void] (Invoke-OpenSsl @sslParams)

        # RETURN PFX PATH
        Write-Output -InputObject $pfxPath
    }
}
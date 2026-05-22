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
    #>
    [CmdletBinding(DefaultParameterSetName = '__nochain')]
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

        [Parameter(Mandatory, ParameterSetName = '__rootonly', HelpMessage = 'Path to root CA public certificate')]
        [Parameter(Mandatory, ParameterSetName = '__fullchain', HelpMessage = 'Path to root CA public certificate')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.crt', '*.cer', '*.pem' })]
        [System.String] $RootCA,

        [Parameter(Mandatory, ParameterSetName = '__fullchain', HelpMessage = 'Path to intermediate CA public certificate')]
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

        # COMBINE CERTIFICATES IN CHAIN (parameter set guarantees RootCA is present when IntermediateCA is)
        switch ($PSCmdlet.ParameterSetName) {
            '__fullchain' {
                $chain = Join-Path -Path $OutputDirectory -ChildPath 'CAChain.crt'
                Get-Content -Path $IntermediateCA | Set-Content -Path $chain
                Get-Content -Path $RootCA | Add-Content -Path $chain
            }
            '__rootonly' {
                $chain = $RootCA
            }
        }

        # CREATE CREDENTIAL OBJECT WITH PASSWORD
        $creds = [System.Management.Automation.PSCredential]::new('UserName', $Password)
    }
    End {
        # SET OPENSSL ARGUMENTS
        # openssl pkcs12 -export -out myDomain.com.pfx -inkey myDomain.com.key -in myDomain.com.crt -certfile CertChain.crt
        # NOTE: -passout pass:... still exposes the password to process listings.
        #       Item 2a will migrate this to -passout env:VAR using the helper.
        $passOutArg = 'pass:{0}' -f $creds.GetNetworkCredential().Password
        $opensslArgs = [System.Collections.Generic.List[System.String]]::new()
        $opensslArgs.AddRange([System.String[]] @(
            'pkcs12', '-export',
            '-out', $pfxPath,
            '-inkey', $Key,
            '-in', $SignedCSR,
            '-passout', $passOutArg
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
        [System.Void] (Invoke-OpenSsl -ArgumentList $opensslArgs.ToArray())

        # RETURN PFX PATH
        Write-Output -InputObject $pfxPath
    }
}
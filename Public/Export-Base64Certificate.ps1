function Export-Base64Certificate {
    <#
    .SYNOPSIS
        Convert a byte array to a base64 encoded string
    .DESCRIPTION
        Convert a byte array to a base64 encoded string
    .PARAMETER ByteArray
        Byte array
    .INPUTS
        None.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> $cert = Get-RemoteSSLCertificate -ComputerName 'example.com'
        PS C:\> Export-Base64Certificate -ByteArray $cert.RawData
        Convert the remote SSL certificate byte array to a base64 encoded string
    .EXAMPLE
        PS C:\> $b64s = Export-Base64Certificate -ByteArray (Get-RemoteSSLCertificate -ComputerName 'example.com').RawData
        PS C:\> $pubCert = @('-----BEGIN CERTIFICATE-----')
        PS C:\> $pubCert += for ($i = 0; $i -LT $b64s.Length; $i += 64) { $b64s.Substring($i, 64) }
        PS C:\> $pubCert += '-----END CERTIFICATE-----'
        Gets the SSL certificate from example.com and converts the raw data to the proper Base64 encoded certificate format
    .NOTES
        Name:     Export-Base64Certificate
        Author:   Justin Johns
        Version:  0.1.0 | Last Edit: 2024-04-19
        - Version history is captured in repository commit history
        Comments: <Comment(s)>
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Byte array')]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]] $ByteArray,

        [Parameter(Mandatory, Position = 1, HelpMessage = 'Path to output certificate file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Directory })]
        [ValidatePattern('^.+\.crt$')]
        [System.String] $Path
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        # CONVERT BYTE ARRAY TO BASE64 ENCODED STRING
        $b64s = [System.Convert]::ToBase64String($ByteArray)

        # SET LENGTH OF BASE64 ENCODED STRING
        $b64sLength = $b64s.Length

        # CREATE ARRAY OF CERTIFICATE DATA
        $pubCert = @('-----BEGIN CERTIFICATE-----')
        $pubCert += for ($i = 0; $i -LT $b64s.Length; $i += 64) {
            if ($b64sLength -ge 64) { $b64s.Substring($i, 64) }
            else { $b64s.Substring($i, $b64sLength) }
            $b64sLength -= 64
        }
        $pubCert += '-----END CERTIFICATE-----'

        # OUTPUT BASE64 ENCODED CERTIFICATE
        Set-Content -Path $Path -Value $pubCert
    }
}

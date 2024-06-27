function Export-Base64Certificate {
    <#
    .SYNOPSIS
        Convert a byte array to a base64 encoded certificate file
    .DESCRIPTION
        Convert a byte array to a base64 encoded certificate file
    .PARAMETER ByteArray
        Byte array
    .PARAMETER Path
        Path to output certificate file
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> $cert = Get-RemoteSSLCertificate -ComputerName 'example.com'
        PS C:\> Export-Base64Certificate -ByteArray $cert.RawData -Path "$HOME\Desktop\example.com.crt"
        Convert the remote SSL certificate byte array to a base64 encoded certificate file and save to the desktop
    .NOTES
        Name:     Export-Base64Certificate
        Author:   Justin Johns
        Version:  0.1.1 | Last Edit: 2024-06-27
        - Version history is captured in repository commit history
        Comments: <Comment(s)>
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Byte array')]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]] $ByteArray,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Path to output certificate file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Directory })]
        [ValidatePattern('^.+\.crt$')]
        [ValidateScript({ -Not (Test-Path -Path $_) })] # ENSURE FILE DOES NOT EXIST
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

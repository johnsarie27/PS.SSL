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
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Byte array')]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]] $ByteArray,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Path to output certificate file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [ValidatePattern('^.+\.crt$')]
        [ValidateScript({ -Not (Test-Path -Path $_) })] # ENSURE FILE DOES NOT EXIST
        [System.String] $Path
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        # Base64-encode and wrap at 64 chars per RFC 7468 (PEM) line width.
        # .NET's Base64FormattingOptions.InsertLineBreaks wraps at 76 (RFC 2045
        # / MIME), so we slice manually to stay PEM-compliant.
        $b64 = [System.Convert]::ToBase64String($ByteArray)
        $lines = for ($i = 0; $i -lt $b64.Length; $i += 64) {
            $take = [System.Math]::Min(64, $b64.Length - $i)
            $b64.Substring($i, $take)
        }
        $pubCert = @('-----BEGIN CERTIFICATE-----') + $lines + '-----END CERTIFICATE-----'

        # OUTPUT BASE64 ENCODED CERTIFICATE
        Set-Content -Path $Path -Value $pubCert
    }
}

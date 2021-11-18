function Test-SSLProtocol {
    <# =========================================================================
    .SYNOPSIS
        Test SSL protcols
    .DESCRIPTION
        Test remote website for SSL protcols
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Test-SSLProtocl -ComputerName 'www.mysite.com'
        Tests www.mysite.com for access using various SSL/TLS protocols
    .NOTES
        General notes
        Original code from:
        https://dscottraynsford.wordpress.com/2016/12/24/test-website-ssl-certificates-continuously-with-powershell-and-pester/
        https://www.sysadmins.lv/blog-en/test-web-server-ssltls-protocol-support-with-powershell.aspx
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Target System')]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter(HelpMessage = 'TCP Port')]
        [ValidateRange(0, 65535)]
        [int] $Port = 443
    )
    Begin {
        $protoProps = [System.Security.Authentication.SslProtocols] | Get-Member -Static -MemberType Property
        $protoNames = ($protoProps | Where-Object Name -notin 'Default', 'None').Name
    }
    Process {
        $protocolStatus = [Ordered] @{
            ComputerName       = $ComputerName
            Port               = $Port
            KeyLength          = $null
            KeyExchange        = $null
            HashAlgorithm      = $null
            SignatureAlgorithm = $null
        }

        foreach ($pn in $protoNames) {

            $socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
            $socket.Connect($ComputerName, $Port)

            try {
                $netStream = New-Object System.Net.Sockets.NetworkStream($socket, $true)
                $sslStream = New-Object System.Net.Security.SslStream($netStream, $true)
                $sslStream.AuthenticateAsClient($ComputerName, $null, $pn, $false )
                $remoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2] $sslStream.RemoteCertificate
                $protocolStatus['KeyLength'] = $remoteCertificate.PublicKey.Key.KeySize
                $protocolStatus['SignatureAlgorithm'] = $remoteCertificate.SignatureAlgorithm.FriendlyName
                $protocolStatus['KeyExchange'] = $sslStream.KeyExchangeAlgorithm
                $protocolStatus['HashAlgorithm'] = $sslStream.HashAlgorithm
                $protocolStatus['Certificate'] = $remoteCertificate
                $protocolStatus.Add($pn, $true)
            }
            catch {
                $protocolStatus.Add($pn, $false)
            }
            finally {
                $socket.Close()
                $sslStream.Close()
            }
        }

        [PSCustomObject] $protocolStatus
    }
}
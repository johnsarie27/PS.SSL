function Test-SSLProtocol {
    <#
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
        Status: Stable
        References:
        https://dscottraynsford.wordpress.com/2016/12/24/test-website-ssl-certificates-continuously-with-powershell-and-pester/
        https://www.sysadmins.lv/blog-en/test-web-server-ssltls-protocol-support-with-powershell.aspx
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'Target System')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ComputerName,

        [Parameter(Position = 1, HelpMessage = 'TCP Port')]
        [ValidateRange(0, 65535)]
        [System.Int32] $Port = 443
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

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

            $socket = $null; $netStream = $null; $sslStream = $null
            try {
                $socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
                $socket.Connect($ComputerName, $Port)
                $netStream = New-Object System.Net.Sockets.NetworkStream($socket, $true)
                $sslStream = New-Object System.Net.Security.SslStream($netStream, $true)
                $sslStream.AuthenticateAsClient($ComputerName, $null, $pn, $false )
                # Build a real X509Certificate2 from the raw cert bytes. The cast
                # [X509Certificate2] $sslStream.RemoteCertificate is not a true upcast
                # (RemoteCertificate is typed as X509Certificate) and would leave the
                # algorithm-specific Get*PublicKey() methods unavailable.
                $remoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)

                # Resolve the public key size via algorithm-specific accessors on the
                # PublicKey object. The legacy PublicKey.Key getter is deprecated and
                # throws NotSupportedException for ECDSA/DSA certs in .NET 5+, which
                # previously caused the whole protocol probe to fall into the catch
                # block for non-RSA endpoints. The Get*PublicKey() methods on
                # X509Certificate2 itself are C# extension methods (not visible to
                # PowerShell instance-method dispatch), so we call them on PublicKey,
                # where they are real instance methods since .NET 5.
                $keySize = $null
                $pk = $remoteCertificate.PublicKey
                $rsa = $pk.GetRSAPublicKey()
                if ($rsa) {
                    $keySize = $rsa.KeySize
                    $rsa.Dispose()
                }
                else {
                    $ecdsa = $pk.GetECDsaPublicKey()
                    if ($ecdsa) {
                        $keySize = $ecdsa.KeySize
                        $ecdsa.Dispose()
                    }
                    else {
                        $dsa = $pk.GetDSAPublicKey()
                        if ($dsa) {
                            $keySize = $dsa.KeySize
                            $dsa.Dispose()
                        }
                    }
                }
                $protocolStatus['KeyLength'] = $keySize
                $protocolStatus['SignatureAlgorithm'] = $remoteCertificate.SignatureAlgorithm.FriendlyName
                $protocolStatus['KeyExchange'] = $sslStream.KeyExchangeAlgorithm
                $protocolStatus['HashAlgorithm'] = $sslStream.HashAlgorithm
                $protocolStatus['Certificate'] = $remoteCertificate
                $protocolStatus.Add($pn, $true)
            }
            catch {
                $protocolStatus.Add($pn, $false)
                Write-Verbose -Message ('Protocol {0} unavailable: {1}' -f $pn, $_.Exception.Message)
            }
            finally {
                # Dispose in reverse construction order. NetworkStream owns the socket
                # (ownsSocket: $true) once constructed, so only close the socket directly
                # when the stream wrapper was never created.
                if ($sslStream)  { $sslStream.Dispose() }
                if ($netStream)  { $netStream.Dispose() }
                elseif ($socket) { $socket.Close() }
            }
        }

        [PSCustomObject] $protocolStatus
    }
}
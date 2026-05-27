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
    .PARAMETER TimeoutSeconds
        Max wait for each TCP connect attempt, in seconds. Bounds total
        wait when a host resolves to many unresponsive addresses
        (default: 3).
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
        [System.Int32] $Port = 443,

        [Parameter(HelpMessage = 'TCP connect timeout, in seconds')]
        [ValidateRange(1, 600)]
        [System.Int32] $TimeoutSeconds = 3
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

        # TCP PRE-FLIGHT. If the endpoint is unreachable, record every
        # protocol as $false up front instead of waiting for Socket.Connect
        # to walk every DNS A record at the OS default connect timeout.
        if (-not (Test-TcpConnection -ComputerName $ComputerName -Port $Port -TimeoutMilliseconds ($TimeoutSeconds * 1000))) {
            Write-Warning -Message ('TCP connect to {0}:{1} failed or timed out after {2}s; reporting all protocols as unsupported.' -f $ComputerName, $Port, $TimeoutSeconds)
            foreach ($pn in $protoNames) { $protocolStatus.Add($pn, $false) }
            [PSCustomObject] $protocolStatus
            return
        }

        $connectTimeoutMs = $TimeoutSeconds * 1000
        foreach ($pn in $protoNames) {

            $socket = $null; $netStream = $null; $sslStream = $null
            try {
                $socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
                # Use the async ConnectAsync + Wait pattern to bound the connect
                # time. Socket.Connect(host, port) has no per-attempt timeout
                # and iterates DNS results at the OS default (~21s/address).
                $connectTask = $socket.ConnectAsync($ComputerName, $Port)
                if (-not $connectTask.Wait($connectTimeoutMs)) {
                    throw [System.TimeoutException]::new(('TCP connect to {0}:{1} timed out after {2}s' -f $ComputerName, $Port, $TimeoutSeconds))
                }
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
function Get-RemoteSSLCertificate {
    <#
    .SYNOPSIS
        Get remote SSL certificate
    .DESCRIPTION
        Get remote SSL certificate
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        --- Example 1: Get remote SSL certificate ---
        PS C:\> Get-RemoteSSLCertificate -ComputerName "www.microsoft.com"
        Get the SSL certificate for www.microsoft.com

        --- Example 2: Get certificate from multipel sites ---
        PS C:\> $sites = @('site1.com', 'www.site2.com', 'site3.com', 'www.site4.com')
        PS C:\> Get-RemoteSSLCertificate -ComputerName $sites | Select-Object NotBefore, NotAfter, Subject
        The first command creates an array of multiple websites. The second commands tests each site and returns the expiry info
    .NOTES
        General notes
        Original code from: https://gist.github.com/jstangroome/5945820
        https://docs.microsoft.com/en-us/archive/blogs/parallel_universe_-_ms_tech_blog/reading-a-certificate-off-a-remote-ssl-server-for-troubleshooting-with-powershell
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'Target System')]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $ComputerName,

        [Parameter(Position = 1, HelpMessage = 'TCP Port')]
        [ValidateRange(1, 65535)]
        [System.Int32] $Port = 443
    )
    Process {

        foreach ($cn in $ComputerName) {

            $certificate = $null
            $tcpClient = New-Object -TypeName System.Net.Sockets.TcpClient

            try {

                $tcpClient.Connect($cn, $Port)
                $tcpStream = $tcpClient.GetStream()

                $callback = { <#param($sender, $cert, $chain, $errors)#> return $true }

                $sslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList @($tcpStream, $true, $callback)

                try {
                    #$sslStream.AuthenticateAsClient('')
                    $sslStream.AuthenticateAsClient($cn)
                    $certificate = $sslStream.RemoteCertificate
                }
                finally {
                    $sslStream.Dispose()
                }
            }
            finally {
                $tcpClient.Dispose()
            }

            if ($certificate) {
                if ($certificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
                    $certificate = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $certificate
                }

                Write-Output -InputObject $certificate
            }
        }
    }
}
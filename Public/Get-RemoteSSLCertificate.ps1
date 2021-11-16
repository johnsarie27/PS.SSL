function Get-RemoteSSLCertificate {
    <# =========================================================================
    .SYNOPSIS
        Get remote SSL certificate
    .DESCRIPTION
        Get remote SSL certificate
    .PARAMETER ComputerName
        Target computer or host
    .PARAMETER Port
        TCP Port
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-RemoteSSLCertificate -ComputerName "www.microsoft.com"
        Get the SSL certificate for www.microsoft.com
    .NOTES
        General notes
        Original code from: https://gist.github.com/jstangroome/5945820
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Target host')]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [Parameter(HelpMessage = 'TCP Port')]
        [ValidateRange(1, 65535)]
        [int] $Port = 443
    )
    Process {

        foreach ($cn in $ComputerName) {

            $certificate = $null
            $tcpClient = New-Object -TypeName System.Net.Sockets.TcpClient

            try {

                $tcpClient.Connect($ComputerName, $Port)
                $tcpStream = $tcpClient.GetStream()

                $callback = { param($sender, $cert, $chain, $errors) return $true }

                $sslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList @($tcpStream, $true, $callback)

                try {
                    $sslStream.AuthenticateAsClient('')
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
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

            $Certificate = $null
            $TcpClient = New-Object -TypeName System.Net.Sockets.TcpClient

            try {

                $TcpClient.Connect($ComputerName, $Port)
                $TcpStream = $TcpClient.GetStream()

                $Callback = { param($sender, $cert, $chain, $errors) return $true }

                $SslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList @($TcpStream, $true, $Callback)

                try {
                    $SslStream.AuthenticateAsClient('')
                    $Certificate = $SslStream.RemoteCertificate
                }
                finally {
                    $SslStream.Dispose()
                }
            }
            finally {
                $TcpClient.Dispose()
            }

            if ($Certificate) {
                if ($Certificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
                    $Certificate = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $Certificate
                }

                Write-Output -InputObject $Certificate
            }
        }
    }
}
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
        System.Security.Cryptography.X509Certificates.X509Certificate2 - returned
        for INSPECTION ONLY. Callers must not treat this certificate as having
        been validated. See the SECURITY note below.
    .EXAMPLE
        --- Example 1: Get remote SSL certificate ---
        PS C:\> Get-RemoteSSLCertificate -ComputerName "www.microsoft.com"
        Get the SSL certificate for www.microsoft.com

        --- Example 2: Get certificate from multipel sites ---
        PS C:\> $sites = @('site1.com', 'www.site2.com', 'site3.com', 'www.site4.com')
        PS C:\> Get-RemoteSSLCertificate -ComputerName $sites | Select-Object NotBefore, NotAfter, Subject
        The first command creates an array of multiple websites. The second commands tests each site and returns the expiry info
    .NOTES
        Status: Stable

        SECURITY: This function intentionally bypasses TLS certificate
        validation. Its purpose is to retrieve the remote certificate -
        including expired, self-signed, hostname-mismatched, or otherwise
        invalid certificates - for inspection and reporting. A validation
        callback that returns $true unconditionally is REQUIRED for that to
        work; refusing the connection on a validation failure would prevent
        us from observing the very certificates an operator needs to see.

        The bypass is scoped to the per-SslStream callback parameter and is
        NOT installed on System.Net.ServicePointManager.ServerCertificateValidationCallback,
        so it does not affect other TLS connections in the PowerShell
        session or in the rest of the process.

        Downstream callers MUST treat the returned X509Certificate2 as
        untrusted data. Do not chain it into trust decisions, pin it, or
        present it as proof of identity.

        References:
        https://gist.github.com/jstangroome/5945820
        https://docs.microsoft.com/en-us/archive/blogs/parallel_universe_-_ms_tech_blog/reading-a-certificate-off-a-remote-ssl-server-for-troubleshooting-with-powershell
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
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

                # INTENTIONAL: accept any server certificate so we can inspect
                # invalid/expired/self-signed ones. See SECURITY note in the
                # function's help. This callback is bound to THIS SslStream
                # only; it is never assigned to ServicePointManager, so it
                # cannot affect other TLS connections in the session.
                $inspectionOnlyValidationCallback = { <#param($sender, $cert, $chain, $errors)#> $true }

                $sslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList @($tcpStream, $true, $inspectionOnlyValidationCallback)

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
                # NOTE: The SslStream was constructed with leaveInnerStreamOpen=$true,
                # so it does NOT close $tcpStream. Disposing $tcpClient also
                # disposes the NetworkStream it owns (returned by GetStream()),
                # which covers the inner stream's lifetime here.
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
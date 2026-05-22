function Test-Cipher {
    <#
    .SYNOPSIS
        Test cipher suite support against a remote endpoint
    .DESCRIPTION
        Probes a host:port with `openssl s_client` requesting a specific
        cipher, and returns a structured result indicating whether the
        handshake succeeded.
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .PARAMETER Cipher
        Cipher
    .INPUTS
        None.
    .OUTPUTS
        PSCustomObject with ComputerName, Port, Cipher, Supported, Error.
    .EXAMPLE
        PS C:\> Test-Cipher -ComputerName myServer.com -Port 443 -Cipher 'ECDHE-RSA-AES128-GCM-SHA256'

        ComputerName Port Cipher                       Supported Error
        ------------ ---- ------                       --------- -----
        myServer.com  443 ECDHE-RSA-AES128-GCM-SHA256       True
    .NOTES
        Name:     Test-Cipher
        Author:   Justin Johns
        Version:  0.2.0 | Last Edit: 2026-05-22
        - Version history is captured in repository commit history
        https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Target System')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ComputerName,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'TCP Port')]
        [ValidateRange(0, 65535)]
        [System.Int32] $Port = 443,

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'Cipher')]
        [ValidateScript({
            if (-not (Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue)) {
                Write-Error -Message "'openssl' was not found on PATH; cannot validate cipher." -Category ObjectNotFound -ErrorAction Stop
            }
            $supported = (& openssl ciphers 2>$null) -split ':'
            if ($_ -notin $supported) {
                Write-Error -Message ("Cipher '{0}' is not in the local openssl cipher list. Run 'openssl ciphers' to view supported values." -f $_) -Category InvalidArgument -ErrorAction Stop
            }
            $true
        })]
        [System.String] $Cipher
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        # openssl s_client -cipher '<CIPHER>' -connect <host:port>
        # Non-zero exit means the server rejected the cipher; use
        # -IgnoreExitCode so we receive the result object instead of a
        # terminating error and can encode the outcome as Supported=$false.
        $endpoint = '{0}:{1}' -f $ComputerName, $Port
        $result = Invoke-OpenSsl -ArgumentList @('s_client', '-cipher', $Cipher, '-connect', $endpoint) -IgnoreExitCode

        [PSCustomObject] @{
            ComputerName = $ComputerName
            Port         = $Port
            Cipher       = $Cipher
            Supported    = ($result.ExitCode -eq 0)
            Error        = if ($result.ExitCode -eq 0) { $null } else { $result.StdErr.Trim() }
        }
    }
}
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
    .PARAMETER TimeoutSeconds
        Max wait for the TCP pre-flight, in seconds. Bounds total wait when
        a host resolves to many unresponsive addresses (default: 3).
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
        Status: Stable
        References:
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
        [System.String] $Cipher,

        [Parameter(HelpMessage = 'TCP connect timeout, in seconds')]
        [ValidateRange(1, 600)]
        [System.Int32] $TimeoutSeconds = 3
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        # TCP PRE-FLIGHT. Without this, an unreachable host that resolves to
        # many addresses (common with split-horizon corp DNS) causes openssl
        # s_client to walk every address at the OS default connect timeout,
        # producing 90+ second hangs. Bound the wait time and short-circuit.
        $endpoint = '{0}:{1}' -f $ComputerName, $Port
        if (-not (Test-TcpConnection -ComputerName $ComputerName -Port $Port -TimeoutMilliseconds ($TimeoutSeconds * 1000))) {
            return [PSCustomObject] @{
                ComputerName = $ComputerName
                Port         = $Port
                Cipher       = $Cipher
                Supported    = $false
                Error        = ('TCP connect to {0} failed or timed out after {1}s' -f $endpoint, $TimeoutSeconds)
            }
        }

        # openssl s_client -cipher '<CIPHER>' -connect <host:port>
        # Non-zero exit means the server rejected the cipher; use
        # -IgnoreExitCode so we receive the result object instead of a
        # terminating error and can encode the outcome as Supported=$false.
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
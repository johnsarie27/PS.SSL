function Test-Protocol {
    <#
    .SYNOPSIS
        Test TLS protocol support against a remote endpoint
    .DESCRIPTION
        Probes a host:port with `openssl s_client` requesting a specific TLS
        protocol version, and returns a structured result indicating whether
        the handshake succeeded.
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .PARAMETER Protocol
        Protocol versions
    .INPUTS
        None.
    .OUTPUTS
        PSCustomObject with ComputerName, Port, Protocol, Supported, Error.
    .EXAMPLE
        PS C:\> Test-Protocol -ComputerName mySever.com -Port 443 -Protocol 'TLS 1.2'

        ComputerName Port Protocol Supported Error
        ------------ ---- -------- --------- -----
        mySever.com   443 TLS 1.2       True
    .NOTES
        Status: Stable
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

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'Protocol version')]
        [ValidateSet('TLS 1.0','TLS 1.1', 'TLS 1.2', 'TLS 1.3')]
        [System.String] $Protocol
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

        # MAP FRIENDLY PROTOCOL NAMES TO openssl s_client SWITCHES
        $protoHash = @{
            'TLS 1.0' = 'tls1'
            'TLS 1.1' = 'tls1_1'
            'TLS 1.2' = 'tls1_2'
            'TLS 1.3' = 'tls1_3'
        }
    }
    Process {
        # openssl.exe s_client -connect <host:port> -<protocol-switch>
        # Non-zero exit means the server rejected the protocol; use
        # -IgnoreExitCode so we receive the result object instead of a
        # terminating error and can encode the outcome as Supported=$false.
        $endpoint = '{0}:{1}' -f $ComputerName, $Port
        $protoSwitch = '-{0}' -f $protoHash[$Protocol]
        $result = Invoke-OpenSsl -ArgumentList @('s_client', '-connect', $endpoint, $protoSwitch) -IgnoreExitCode

        # On a successful handshake openssl writes the negotiated session to
        # stdout and exits with code 0; on rejection it writes a diagnostic
        # to stderr ("handshake failure", "no protocols available", etc.) and
        # exits non-zero. Trim stderr for readability and only surface it on
        # the failure path.
        [PSCustomObject] @{
            ComputerName = $ComputerName
            Port         = $Port
            Protocol     = $Protocol
            Supported    = ($result.ExitCode -eq 0)
            Error        = if ($result.ExitCode -eq 0) { $null } else { $result.StdErr.Trim() }
        }
    }
}
function Test-TcpConnection {
    <#
    .SYNOPSIS
        Probe TCP reachability of a remote endpoint with a bounded timeout.
    .DESCRIPTION
        Internal helper used by the SSL/TLS probing cmdlets (Test-Protocol,
        Test-Cipher, Test-SSLProtocol) to short-circuit when the target
        endpoint is unreachable. openssl s_client and System.Net.Sockets.Socket
        both iterate through every DNS A record sequentially using the OS
        default connect timeout (~21s/address on Windows), which produces
        90+ second hangs when a host resolves to many addresses that drop
        traffic (typical on corp networks with split-horizon DNS).

        TcpClient.ConnectAsync still walks every resolved address internally,
        but Task.Wait(TimeoutMilliseconds) caps the total wall-clock time
        we'll spend waiting regardless of how many addresses are tried.
    .PARAMETER ComputerName
        Target host name or IP.
    .PARAMETER Port
        TCP port.
    .PARAMETER TimeoutMilliseconds
        Maximum total time to wait for a successful connect, in milliseconds.
        Defaults to 3000.
    .INPUTS
        None.
    .OUTPUTS
        System.Boolean. $true if a TCP connection was established within the
        timeout window; otherwise $false.
    .EXAMPLE
        PS C:\> Test-TcpConnection -ComputerName example.com -Port 443 -TimeoutMilliseconds 3000
    .NOTES
        Status: Stable
        - Internal helper. Not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Target host name or IP')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ComputerName,

        [Parameter(Mandatory, Position = 1, HelpMessage = 'TCP port')]
        [ValidateRange(0, 65535)]
        [System.Int32] $Port,

        [Parameter(Position = 2, HelpMessage = 'Maximum total wait, in milliseconds')]
        [ValidateRange(1, 600000)]
        [System.Int32] $TimeoutMilliseconds = 3000
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
    }
    Process {
        # TcpClient.ConnectAsync(host, port) resolves the host and attempts
        # each address in sequence. Task.Wait returns $false if the timeout
        # elapses before completion; in that case we abandon the in-flight
        # task by disposing the client (which cancels the underlying socket).
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $task = $client.ConnectAsync($ComputerName, $Port)
            if ($task.Wait($TimeoutMilliseconds)) {
                return $client.Connected
            }
            return $false
        }
        catch {
            # DNS failure, host unreachable mid-attempt, etc. Probe is a
            # boolean reachability check - swallow the exception and let
            # the caller treat the endpoint as unreachable.
            Write-Verbose -Message ('TCP probe of {0}:{1} failed: {2}' -f $ComputerName, $Port, $_.Exception.Message)
            return $false
        }
        finally {
            $client.Dispose()
        }
    }
}

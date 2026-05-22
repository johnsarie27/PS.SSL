function Test-Cipher {
    <#
    .SYNOPSIS
        Test cipher suites
    .DESCRIPTION
        Test cipher suites
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .PARAMETER Cipher
        Cipher
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Test-Cipher -ComputerName myServer.com -Port 443 -Cipher 'ECDHE-RSA-AES128-GCM-SHA256'
        Uses openssl to test connecting to myServer.com over port 443 using the cipher 'ECDHE-RSA-AES128-GCM-SHA256'
    .NOTES
        Name:     Test-Cipher
        Author:   Justin Johns
        Version:  0.1.0 | Last Edit: 2023-12-21
        - Version history is captured in repository commit history
        Comments:
        https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
    #>
    [CmdletBinding()]
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
        # openssl s_client -cipher '<CIPHER>' -connect <IP/HostName>:<Port>
        # A non-zero exit means the server rejected the cipher; preserve the
        # existing non-terminating Write-Error behavior. Item 3b will rework
        # this to return a structured object.
        $endpoint = '{0}:{1}' -f $ComputerName, $Port
        $result = Invoke-OpenSsl -ArgumentList @('s_client', '-cipher', $Cipher, '-connect', $endpoint) -IgnoreExitCode

        if ($result.ExitCode -ne 0) {
            Write-Error -Message ('openssl failed with exit code {0}: {1}' -f $result.ExitCode, $result.StdErr.Trim())
        }
        else {
            $result.StdOut
        }
    }
}
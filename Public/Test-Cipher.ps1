function Test-Cipher {
    <# =========================================================================
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
        - 0.1.0 - Initial version
        Comments:
        https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Target System')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ComputerName,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'TCP Port')]
        [ValidateRange(0, 65535)]
        [System.Int32] $Port = 443,

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'Cipher')]
        [ValidateScript({ $_ -in ((openssl ciphers) -split ':') })]
        [System.String] $Cipher
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        # SET SSL PARAMETERS
        $sslParams = @{
            FilePath = 'openssl'
            ArgumentList = @(
                # openssl s_client -cipher '<CIPHER>' -connect <IP/HostName>:<Port>
                's_client -cipher {0} -connect {1}:{2}' -f $Cipher, $ComputerName, $Port
            )
            Wait = $true; NoNewWindow = $true; PassThru = $true
        }

        # GENERATE CERTIFICATE FILES USING OPENSSL
        $proc = Start-Process @sslParams

        # VALIDATE RESPONSE
        if ($proc.ExitCode -NE 0) {
            Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode)
        }
    }
}
function Test-Protocol {
    <#
    .SYNOPSIS
        Test TLS protocol
    .DESCRIPTION
        Test TLS protocol
    .PARAMETER ComputerName
        Target Computer System
    .PARAMETER Port
        TCP Port
    .PARAMETER Protocol
        Protocol versions
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Test-Protocol -ComputerName mySever.com -Port 443 -Protocl 'TLS 1.2'
        Uses openssl to test connecting to myServer.com over port 443 using TLS 1.2
    .NOTES
        Name:     Test-Protocol
        Author:   Justin Johns
        Version:  0.1.0 | Last Edit: 2023-12-21
        - 0.1.0 - Initial version
        Comments:
    #>
    [CmdletBinding()]
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

        # SET HASH TABLE FOR PROTOCOL
        $protoHash = @{
            'TLS 1.0' = 'tls1'
            'TLS 1.1' = 'tls1_1'
            'TLS 1.2' = 'tls1_2'
            'TLS 1.3' = 'tls1_3'
        }
    }
    Process {
        # SET SSL PARAMETERS
        $sslParams = @{
            FilePath     = 'openssl'
            ArgumentList = @(
                #openssl.exe s_client -connect 10.0.0.24:3389 -tls1
                's_client -connect {0}:{1} -{2}' -f $ComputerName, $Port, $protoHash[$Protocol]
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
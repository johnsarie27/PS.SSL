function Confirm-SignedCSR {
    <# =========================================================================
    .SYNOPSIS
        Confirm signed CSR
    .DESCRIPTION
        Confirm/validate details of signed certificate request
    .PARAMETER SignedCSR
        Path to certificate signing request
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .NOTES
        General notes
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to CA-signed certificate request')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.crt", "*.cer" })]
        [string] $SignedCSR
    )
    Process {
        # VERIFY SIGNED CERTIFICATE
        # openssl x509 -text -noout -in <Public_Key_Signed>.crt
        $sslParams = @{
            FilePath     = 'openssl.exe'
            ArgumentList = @(
                'x509 -text -noout'
                '-in {0}' -f $SignedCSR
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
    }
}
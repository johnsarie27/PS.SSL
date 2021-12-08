function Get-CertificateData {
    <# =========================================================================
    .SYNOPSIS
        Get x509 certificate details
    .DESCRIPTION
        Get x509 certificate details
    .PARAMETER Path
        Path to x509 certificate file
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
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to x509 certificate file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.crt", "*.cer", "*.pem" })]
        [string] $Path
    )
    Process {
        # VERIFY SIGNED CERTIFICATE
        # openssl x509 -text -noout -in <Public_Key_Signed>.crt
        $sslParams = @{
            FilePath     = 'openssl' # .exe
            ArgumentList = @(
                'x509 -text -noout'
                '-in {0}' -f $Path
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
    }
}
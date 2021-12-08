function Confirm-CSR {
    <# =========================================================================
    .SYNOPSIS
        Confirm CSR
    .DESCRIPTION
        Confirm/validate details of certificate signing request (CSR)
    .PARAMETER CSR
        Path to certificate signing request (CSR)
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
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csr" })]
        [string] $CSR
    )
    Process {
        # VERIFY UNSIGNED CSR
        # openssl req -text -noout -verify -in company_san.csr
        $sslParams = @{
            FilePath     = 'openssl' # .exe
            ArgumentList = @(
                'req -text -noout -verify'
                '-in {0}' -f $CSR
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
    }
}
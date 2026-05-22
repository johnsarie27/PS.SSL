function Get-CSRData {
    <#
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
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to CA-signed certificate request')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csr" })]
        [System.String] $CSR
    )
    Process {
        # VERIFY UNSIGNED CSR
        # openssl req -text -noout -verify -in company_san.csr
        $result = Invoke-OpenSsl -ArgumentList @('req', '-text', '-noout', '-verify', '-in', $CSR)
        $result.StdOut
    }
}
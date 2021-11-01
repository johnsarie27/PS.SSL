function New-CSR {
    <# =========================================================================
    .SYNOPSIS
        Generate new CSR and Private key file
    .DESCRIPTION
        Generate new CSR and Private key file
    .PARAMETER OutputDirectory
        Output directory for CSR and key file
    .PARAMETER CN
        Common Name (CN)
    .PARAMETER SAN1
        Subject Alternative Name (SAN) 1
    .PARAMETER SAN2
        Subject Alternative Name (SAN) 2
    .PARAMETER SAN3
        Subject Alternative Name (SAN) 3
    .PARAMETER KeepConfig
        Preserve CSR configuration template
    .INPUTS
        None.
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
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [string] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, HelpMessage = 'Common Name (CN)')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $CN, # 'www.company.com'

        [Parameter(HelpMessage = 'Subject Alternative Name (SAN) 1')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN1, # 'company.com'

        [Parameter(HelpMessage = 'Subject Alternative Name (SAN) 2')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN2, # 'www.company.net'

        [Parameter(HelpMessage = 'Subject Alternative Name (SAN) 3')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN3, # 'company.net'

        [Parameter(HelpMessage = 'Preserve CSR configuration template')]
        [switch] $KeepConfig
    )
    Begin {
        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) { New-Item -Path $OutputDirectory -ItemType Directory }

        # GET TEMPLATE
        $request = [System.Collections.ArrayList]::new((Get-Content -Path $CSR_Template))

        # SET REPLACEMENT TOKENS
        $tokenList = @{ CN = $CN }
        if ($PSBoundParameters.ContainsKey('SAN1')) { $tokenList.Add('SAN1', $SAN1) } else { $request.Remove('DNS.2 = #SAN1#') }
        if ($PSBoundParameters.ContainsKey('SAN2')) { $tokenList.Add('SAN2', $SAN2) } else { $request.Remove('DNS.3 = #SAN2#') }
        if ($PSBoundParameters.ContainsKey('SAN3')) { $tokenList.Add('SAN3', $SAN3) } else { $request.Remove('DNS.4 = #SAN3#') }

        # REPLACE TOKENS
        foreach ( $token in $tokenList.GetEnumerator() ) {
            $pattern = '#{0}#' -f $token.key
            $request = $request -replace $pattern, $token.Value
        }

        # SET TEMPLATE FILE WITH NEW VALUES
        $templatePath = Join-Path -Path $OutputDirectory -ChildPath 'request_template.conf'
        $request | Set-Content -Path $templatePath
    }
    End {
        # SET OPENSSL PARAMETERS
        # openssl req -new -out company_san.csr -newkey rsa:2048 -nodes -sha256 -keyout company_san.key -config req.conf
        $sslParams = @{
            FilePath     = 'openssl.exe'
            ArgumentList = @(
                'req -new'
                '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.csr' -f $CN))
                '-newkey rsa:2048'
                '-nodes -sha256'
                '-keyout {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.key' -f $CN))
                '-config {0}' -f $templatePath
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode) }

        # REMOVE TEMPLATE
        if (!$PSBoundParameters.ContainsKey('KeepConfig')) { Remove-Item -Path $templatePath -Confirm:$false }
    }
}
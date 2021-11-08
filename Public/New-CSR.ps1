function New-CSR {
    <# =========================================================================
    .SYNOPSIS
        Generate new CSR and Private key file
    .DESCRIPTION
        Generate new CSR and Private key file
    .PARAMETER OutputDirectory
        Output directory for CSR and key file
    .PARAMETER ConfigFile
        Path to configuration template file
    .PARAMETER CN
        Common Name (CN)
    .PARAMETER SAN1
        Subject Alternative Name (SAN) 1
    .PARAMETER SAN2
        Subject Alternative Name (SAN) 2
    .PARAMETER SAN3
        Subject Alternative Name (SAN) 3
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
    [CmdletBinding(DefaultParameterSetName = '__template')]
    Param(
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [string] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, ParameterSetName = '__template', HelpMessage = 'Path to configuration template')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.conf' })]
        [string] $ConfigFile,

        [Parameter(Mandatory, ParameterSetName = '__manual', HelpMessage = 'Common Name (CN)')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $CN, # 'www.company.com'

        [Parameter(ParameterSetName = '__manual', HelpMessage = 'Subject Alternative Name (SAN) 1')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN1, # 'company.com'

        [Parameter(ParameterSetName = '__manual', HelpMessage = 'Subject Alternative Name (SAN) 2')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN2, # 'www.company.net'

        [Parameter(ParameterSetName = '__manual', HelpMessage = 'Subject Alternative Name (SAN) 3')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN3 # 'company.net'
    )
    Begin {
        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) { New-Item -Path $OutputDirectory -ItemType Directory | Out-Null }
        Write-Verbose -Message ('Creating new folder named: {0}' -f (Split-Path -Path $OutputDirectory -Leaf))

        # SET PARAMETERS FOR MANUAL TEMPALTE GENERATION
        if ($PSCmdlet.ParameterSetName -EQ '__manual') {
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
            $random = [System.IO.Path]::GetRandomFileName().Split('.')[0]
            $ConfigFile = Join-Path -Path $OutputDirectory -ChildPath ('request_template_{0}.conf' -f $random)
            $request | Set-Content -Path $ConfigFile
        }
    }
    End {
        # SET FILE NAME
        $selectPattern = Get-Content -Path $ConfigFile | Select-String -Pattern '^CN = (.+)$'
        $fileName = $selectPattern.Matches.Groups[1].Value
        Write-Verbose -Message ('New file name: {0}' -f $fileName)

        # SET OPENSSL PARAMETERS
        # openssl req -new -out company_san.csr -newkey rsa:2048 -nodes -sha256 -keyout company_san.key -config req.conf
        $sslParams = @{
            FilePath     = 'openssl.exe'
            ArgumentList = @(
                'req -new'
                '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.csr' -f $fileName))
                '-newkey rsa:2048'
                '-nodes -sha256'
                '-keyout {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName))
                '-config {0}' -f $ConfigFile
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode) }
    }
}
function New-SelfSignedCertificate {
    <# =========================================================================
    .SYNOPSIS
        Generate new self-signed certificate
    .DESCRIPTION
        Generate new self-signed certificate with openssl
    .PARAMETER OutputDirectory
        Output directory for CSR and key file
    .PARAMETER Days
        Validity period in days (default is 365)
    .PARAMETER ConfigFile
        Path to configuration template file
    .PARAMETER CommonName
        Common Name (CN)
    .PARAMETER Country
        Country Name (C)
    .PARAMETER State
        State or Province Name (ST)
    .PARAMETER Locality
        Locality Name (L)
    .PARAMETER Organization
        Organization Name (O)
    .PARAMETER OrganizationalUnit
        Organizational Unit Name (OU)
    .PARAMETER Email
        Email Address
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
        PS C:\> New-SelfSignedCertificate
        Explanation of what the example does
    .NOTES
        Name:      New-SelfSignedCertificate
        Author:    Justin Johns
        Version:   0.1.1 | Last Edit: 2022-04-13
        - Renamed output template file
        Comments: <Comment(s)>
        General notes
    ========================================================================= #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = '__conf')]
    Param(
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(HelpMessage = 'Validity period in days (default is 365)')]
        [ValidateRange(30, 3650)]
        [System.String] $Days = 365,

        [Parameter(Mandatory, ParameterSetName = '__conf', HelpMessage = 'Path to configuration template')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.conf' })]
        [System.String] $ConfigFile,

        [Parameter(Mandatory, ParameterSetName = '__input', HelpMessage = 'Common Name (CN)')]
        [Alias('CN')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov|internal|local)$')]
        [System.String] $CommonName,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Country Name (C)')]
        [Alias('C')]
        [ValidatePattern('^[A-Z]{2}$')]
        [System.String] $Country,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'State or Province Name (ST)')]
        [Alias('ST')]
        [ValidatePattern('^[\w\s-]+$')]
        [System.String] $State,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Locality Name (L)')]
        [Alias('L')]
        [ValidatePattern('^[\w\s-]+$')]
        [System.String] $Locality,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Organization Name (O)')]
        [Alias('O')]
        [ValidatePattern('^[\w\.\s-]+$')]
        [System.String] $Organization,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Organizational Unit Name (OU)')]
        [Alias('OU')]
        [ValidatePattern('^[\w\.\s-]+$')]
        [System.String] $OrganizationalUnit,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Email Address')]
        [ValidatePattern('^[\w\.@-]+$')]
        [System.String] $Email,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 1')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [System.String] $SAN1,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 2')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [System.String] $SAN2,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 3')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [System.String] $SAN3
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
        Write-Verbose -Message ('Parameter Set: {0}' -f $PSCmdlet.ParameterSetName)

        # SHOULD PROCESS
        if ($PSCmdlet.ShouldProcess($OutputDirectory, "Create Files")) {

            # CREATE OUTPUT DIRECTORY
            if (-not (Test-Path -Path $OutputDirectory)) {

                Write-Verbose -Message ('Creating new folder named: {0}' -f (Split-Path -Path $OutputDirectory -Leaf))
                New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
            }

            # CREATE TEMPLATE FILE
            if ($PSCmdlet.ParameterSetName -eq '__input') {
                # GET TEMPLATE
                $template = [System.Collections.ArrayList]::new($CSR_Template)

                # SET REPLACEMENT TOKENS
                $tokenList = @{ CN = $CommonName }
                if ($PSBoundParameters.ContainsKey('Country')) { $tokenList.Add('C', $Country) } else { $template.Remove('C = #C#') }
                if ($PSBoundParameters.ContainsKey('State')) { $tokenList.Add('ST', $State) } else { $template.Remove('ST = #ST#') }
                if ($PSBoundParameters.ContainsKey('Locality')) { $tokenList.Add('L', $Locality) } else { $template.Remove('L = #L#') }
                if ($PSBoundParameters.ContainsKey('Organization')) { $tokenList.Add('O', $Organization) } else { $template.Remove('O = #O#') }
                if ($PSBoundParameters.ContainsKey('OrganizationalUnit')) { $tokenList.Add('OU', $OrganizationalUnit) } else { $template.Remove('OU = #OU#') }
                if ($PSBoundParameters.ContainsKey('Email')) { $tokenList.Add('E', $Email) } else { $template.Remove('emailAddress = "#E#"') }
                if ($PSBoundParameters.ContainsKey('SAN1')) { $tokenList.Add('SAN1', $SAN1) } else { $template.Remove('DNS.2 = #SAN1#') }
                if ($PSBoundParameters.ContainsKey('SAN2')) { $tokenList.Add('SAN2', $SAN2) } else { $template.Remove('DNS.3 = #SAN2#') }
                if ($PSBoundParameters.ContainsKey('SAN3')) { $tokenList.Add('SAN3', $SAN3) } else { $template.Remove('DNS.4 = #SAN3#') }

                # REPLACE TOKENS
                foreach ( $token in $tokenList.GetEnumerator() ) {
                    $pattern = '#{0}#' -f $token.key
                    $template = $template -replace $pattern, $token.Value
                }

                # SHOW TEMPLATE
                Write-Verbose -Message ($template -join "`n")

                # SET TEMPLATE FILE PATH
                $random = [System.IO.Path]::GetRandomFileName().Split('.')[0]
                $configPath = Join-Path -Path $OutputDirectory -ChildPath ('template_{0}.conf' -f $random)

                # CREATE TEMPLATE FILE
                Set-Content -Path $configPath -Value $template -Confirm:$false
            }
            else {
                $configPath = $ConfigFile
            }

            # SET FILE NAME
            $selectPattern = Get-Content -Path $configPath | Select-String -Pattern '^CN = (.+)$'
            $fileName = $selectPattern.Matches.Groups[1].Value

            # THE CHARACTER "*" IS NOT VALID IN A WINDOWS FILENAME. REPLACE "*" WITH "STAR"
            if ($fileName -match '\*') { $fileName = $fileName.Replace('*', 'star') }
            Write-Verbose -Message ('New file name: {0}' -f $fileName)

            # SET OPENSSL PARAMETERS
            # openssl req -new -newkey rsa:2048 -nodes -sha256 -out company_san.csr -keyout company_san.key -config req.conf
            # USING THE "-legacy" PARAMETER WILL MAINTAIN COMPATABILITY WITH CERTAIN SERVERS THAT DO NOT YET SUPPORT
            # THE LATEST CIPHERS OR PROTOCOLS
            # EXAMPLE> openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365
            # -newkey rsa:4096 and -sha256 are in the default template
            $sslParams = @{
                FilePath     = 'openssl'
                ArgumentList = @(
                    'req -new -x509 -nodes -days {0}' -f $Days
                    '-config {0}' -f $configPath
                    '-keyout {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName))
                    '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.pem' -f $fileName))
                )
                Wait         = $true
                NoNewWindow  = $true
                PassThru     = $true
            }

            # GENERATE CERTIFICATE FILES USING OPENSSL
            $proc = Start-Process @sslParams

            if ($proc.ExitCode -NE 0) {
                Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode)
            }
        }
    }
}
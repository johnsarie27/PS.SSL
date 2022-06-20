function New-CSR {
    <# =========================================================================
    .SYNOPSIS
        Generate new CSR and Private key file
    .DESCRIPTION
        Generate new CSR and Private key file
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
        PS C:\> New-CSR -CommonName www.myDomain.com
        Creates a new CSR and private key for www.myDomain.com
    .NOTES
        Name:      New-CSR
        Author:    Justin Johns
        Version:   0.1.1 | Last Edit: 2022-06-20
        - 0.1.0 - Initial versions
        - 0.1.1 - Added SupportsShouldProcess
        General notes
        Example commands
        openssl req -newkey rsa:2048 -sha256 -keyout PRIVATEKEY.key -out MYCSR.csr -subj "/C=US/ST=CA/L=Redlands/O=Esri/CN=myDomain.com"
        openssl req -new -newkey rsa:2048 -nodes -sha256 -out company_san.csr -keyout company_san.key -config req.conf
    ========================================================================= #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = '__conf')]
    Param(
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [string] $OutputDirectory = "$HOME\Desktop",

        [Parameter(HelpMessage = 'Validity period in days (default is 365)')]
        [ValidateRange(30, 3650)]
        [System.String] $Days = 365,

        [Parameter(Mandatory, ParameterSetName = '__conf', HelpMessage = 'Path to configuration template')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.conf' })]
        [string] $ConfigFile,

        [Parameter(Mandatory, ParameterSetName = '__input', HelpMessage = 'Common Name (CN)')]
        [Alias('CN')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $CommonName,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Country Name (C)')]
        [Alias('C')]
        [ValidatePattern('^[A-Z]{2}$')]
        [string] $Country,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'State or Province Name (ST)')]
        [Alias('ST')]
        [ValidatePattern('^[\w\s-]+$')]
        [string] $State,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Locality Name (L)')]
        [Alias('L')]
        [ValidatePattern('^[\w\s-]+$')]
        [string] $Locality,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Organization Name (O)')]
        [Alias('O')]
        [ValidatePattern('^[\w\.\s-]+$')]
        [string] $Organization,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Organizational Unit Name (OU)')]
        [Alias('OU')]
        [ValidatePattern('^[\w\.\s-]+$')]
        [string] $OrganizationalUnit,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Email Address')]
        [ValidatePattern('^[\w\.@-]+$')]
        [string] $Email,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 1')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN1,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 2')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN2,

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN) 3')]
        [ValidatePattern('^[\w\.-]+\.(com|org|gov)$')]
        [string] $SAN3
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
        Write-Verbose -Message ('Parameter Set: {0}' -f $PSCmdlet.ParameterSetName)

        # SHOULD PROCESS
        if ($PSCmdlet.ShouldProcess($OutputDirectory, "Create Files")) {

            # GET OUTPUT DIRECTORY
            if (-not (Test-Path -Path $OutputDirectory)) {
                Write-Verbose -Message ('Creating new folder named: {0}' -f (Split-Path -Path $OutputDirectory -Leaf))
                New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
            }


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

                # SET TEMPLATE FILE WITH NEW VALUES
                $random = [System.IO.Path]::GetRandomFileName().Split('.')[0]
                $configPath = Join-Path -Path $OutputDirectory -ChildPath ('csr_template_{0}.conf' -f $random)

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
            # EXAMPLE> openssl pkcs12 -export -legacy -out example.pfx -inkey example.key -in example.crt
            $sslParams = @{
                FilePath     = 'openssl' # .exe
                ArgumentList = @(
                    'req -new -nodes -days {0}' -f $Days
                    '-config {0}' -f $configPath
                    '-keyout {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName))
                    '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.csr' -f $fileName))
                )
                Wait         = $true
                NoNewWindow  = $true
                PassThru     = $true
            }
            $proc = Start-Process @sslParams

            if ($proc.ExitCode -NE 0) {
                Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode)
            }
        }
    }
}
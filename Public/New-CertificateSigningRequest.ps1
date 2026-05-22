function New-CertificateSigningRequest {
    <#
    .SYNOPSIS
        Generate new CSR and Private key file
    .DESCRIPTION
        Generate new CSR and Private key file
    .PARAMETER OutputDirectory
        Output directory for CSR and key file
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
    .PARAMETER SubjectAlternativeName
        Subject Alternative Name (SAN)
    .PARAMETER KeySize
        RSA key size in bits (2048, 3072, or 4096; default is 4096). Emitted explicitly to openssl so the result is deterministic regardless of the config template contents.
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> New-CertificateSigningRequest -CommonName www.myDomain.com
        Creates a new CSR and private key for www.myDomain.com
    .NOTES
        Name:      New-CertificateSigningRequest
        Author:    Justin Johns
        Version:   0.3.0 | Last Edit: 2026-05-22
        - Version history is captured in repository commit history
        General notes
        Example commands
        openssl req -newkey rsa:2048 -sha256 -keyout PRIVATEKEY.key -out MYCSR.csr -subj "/C=US/ST=CA/L=Redlands/O=Esri/CN=myDomain.com"
        openssl req -new -newkey rsa:2048 -nodes -sha256 -out company_san.csr -keyout company_san.key -config req.conf
    #>
    [Alias('New-CSR')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = '__conf')]
    Param(
        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, ParameterSetName = '__conf', HelpMessage = 'Path to configuration template')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.conf' })]
        [System.String] $ConfigFile,

        [Parameter(Mandatory, ParameterSetName = '__input', HelpMessage = 'Common Name (CN)')]
        [Alias('CN')]
        # TLD allow-list reflects the domain scope this module is deployed against.
        # Update both CommonName and SubjectAlternativeName together if the policy changes.
        [ValidatePattern('^[\w\.-]+\.(com|org|gov|info)$')]
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

        [Parameter(ParameterSetName = '__input', HelpMessage = 'Subject Alternative Name (SAN)')]
        [Alias('SAN')]
        # TLD allow-list must match CommonName above.
        [ValidatePattern('^[\w\.-]+\.(com|org|gov|info)$')]
        [System.String[]] $SubjectAlternativeName,

        [Parameter(HelpMessage = 'RSA key size in bits (default 4096)')]
        [ValidateSet(2048, 3072, 4096)]
        [System.Int32] $KeySize = 4096
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
        Write-Verbose -Message ('Parameter Set: {0}' -f $PSCmdlet.ParameterSetName)

        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) {
            Write-Verbose -Message ('Creating new folder named: {0}' -f (Split-Path -Path $OutputDirectory -Leaf))
            New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
        }

        # BUILD CSR BASED ON PARAMETER INPUT
        if ($PSCmdlet.ParameterSetName -eq '__input') {
            # CREATE NEW LIST
            $template = [System.Collections.ArrayList]::new()

            # ADD TEMPLATE TO LIST
            $template.AddRange($CSR_Template)

            # ADD SUBJECT ALTERNATIVE NAMES TO LIST
            if ($PSBoundParameters.ContainsKey('SubjectAlternativeName')) {
                # EVALUATE EACH SAN IN ARRAY
                for ($i = 1; $i -lt ($SubjectAlternativeName.Count + 1); $i++) {
                    # ADD SAN TO END OF COLLECTION
                    $template.Add(('DNS.{0} = {1}' -f $i, $SubjectAlternativeName[$i - 1])) | Out-Null
                }
            }

            # SET REPLACEMENT TOKENS
            $tokenList = @{ CN = $CommonName }
            if ($PSBoundParameters.ContainsKey('Country')) { $tokenList.Add('C', $Country) } else { $template.Remove('C = #C#') }
            if ($PSBoundParameters.ContainsKey('State')) { $tokenList.Add('ST', $State) } else { $template.Remove('ST = #ST#') }
            if ($PSBoundParameters.ContainsKey('Locality')) { $tokenList.Add('L', $Locality) } else { $template.Remove('L = #L#') }
            if ($PSBoundParameters.ContainsKey('Organization')) { $tokenList.Add('O', $Organization) } else { $template.Remove('O = #O#') }
            if ($PSBoundParameters.ContainsKey('OrganizationalUnit')) { $tokenList.Add('OU', $OrganizationalUnit) } else { $template.Remove('OU = #OU#') }
            if ($PSBoundParameters.ContainsKey('Email')) { $tokenList.Add('E', $Email) } else { $template.Remove('emailAddress = "#E#"') }

            # REMOVE SAN FROM TEMPLATE IF NOT PROVIDED
            if (-Not $PSBoundParameters.ContainsKey('SubjectAlternativeName')) {
                $template.Remove('[alt_names]')
                $template.Remove('subjectAltName = @alt_names')
            }

            # REPLACE TOKENS IN TEMPLATE
            foreach ($token in $tokenList.GetEnumerator()) {
                $pattern = '#{0}#' -f $token.key
                $template = $template -replace $pattern, $token.Value
            }

            # SHOW TEMPLATE
            Write-Verbose -Message ("`n" + ($template -join "`n"))

            # SET TEMPLATE FILE WITH NEW VALUES
            $random = [System.IO.Path]::GetRandomFileName().Split('.')[0]
            $configPath = Join-Path -Path $OutputDirectory -ChildPath ('csr_template_{0}.conf' -f $random)

            # CREATE TEMPLATE FILE
            Set-Content -Path $configPath -Value $template -Confirm:$false

            # OUTPUT TEMPLATE PATH
            Write-Verbose -Message ('Template file path: [{0}]' -f $configPath)
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
        # NOTE: -days is intentionally NOT passed here. `openssl req` ignores it
        # unless -x509 is also specified, and CSRs by design carry no validity
        # period; the issuing CA sets validity at signing time.
        # -newkey/-sha256 are emitted explicitly so the result is deterministic
        # even when a custom -ConfigFile omits default_bits/default_md.
        $sslParams = @{
            FilePath     = 'openssl' # .exe
            ArgumentList = @(
                'req -new -nodes -newkey rsa:{0} -sha256' -f $KeySize
                '-config {0}' -f $configPath
                '-keyout {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName))
                '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath ('{0}.csr' -f $fileName))
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }

        # SHOULD PROCESS
        if ($PSCmdlet.ShouldProcess($OutputDirectory, "Create Files")) {

            # INVOKE OPENSSL
            $proc = Start-Process @sslParams

            # CHECK FOR ERRORS
            if ($proc.ExitCode -NE 0) {
                # OUTPUT ERROR
                Write-Error -Message ('openssl failed with exit code: {0}' -f $proc.ExitCode)
            }
        }
    }
}
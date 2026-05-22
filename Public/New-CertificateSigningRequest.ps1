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
        None. Writes three files into -OutputDirectory:
          <CN>.csr          - the certificate signing request
          <CN>_PRIVATE.key  - the matching private key (unencrypted)
          <CN>.conf         - the openssl req config used to produce them,
                              preserved as a reproducible record of the
                              inputs. Only written when the cmdlet is invoked
                              in the __input parameter set; -ConfigFile mode
                              leaves the caller's file alone.
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
        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
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
        Initialize-OutputDirectory -Path $OutputDirectory

        # BUILD CSR BASED ON PARAMETER INPUT
        if ($PSCmdlet.ParameterSetName -eq '__input') {
            # CN is the source of truth for the artifact basename, so derive it
            # here rather than reading it back from the rendered .conf.
            $fileName = $CommonName

            # THE CHARACTER "*" IS NOT VALID IN A WINDOWS FILENAME. REPLACE "*" WITH "STAR"
            if ($fileName -match '\*') { $fileName = $fileName.Replace('*', 'star') }

            # The .conf is intentionally preserved alongside the .csr / .key
            # outputs as a reproducible record of the request inputs. Name it
            # after the CN so all sibling artifacts group visually.
            $configPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.conf' -f $fileName)

            # DELEGATE TEMPLATE RENDERING TO PRIVATE HELPER
            $buildParams = @{ CommonName = $CommonName; OutputPath = $configPath }
            foreach ($key in 'Country', 'State', 'Locality', 'Organization', 'OrganizationalUnit', 'Email', 'SubjectAlternativeName') {
                if ($PSBoundParameters.ContainsKey($key)) { $buildParams[$key] = $PSBoundParameters[$key] }
            }
            Build-CsrConfig @buildParams
        }
        else {
            $configPath = $ConfigFile

            # SET FILE NAME (extract CN from caller-supplied config)
            $selectPattern = Get-Content -Path $configPath | Select-String -Pattern '^CN = (.+)$'
            $fileName = $selectPattern.Matches.Groups[1].Value

            # THE CHARACTER "*" IS NOT VALID IN A WINDOWS FILENAME. REPLACE "*" WITH "STAR"
            if ($fileName -match '\*') { $fileName = $fileName.Replace('*', 'star') }
        }
        Write-Verbose -Message ('New file name: {0}' -f $fileName)

        # SET OPENSSL ARGUMENTS
        # openssl req -new -newkey rsa:2048 -nodes -sha256 -out company_san.csr -keyout company_san.key -config req.conf
        # USING THE "-legacy" PARAMETER WILL MAINTAIN COMPATABILITY WITH CERTAIN SERVERS THAT DO NOT YET SUPPORT
        # THE LATEST CIPHERS OR PROTOCOLS
        # EXAMPLE> openssl pkcs12 -export -legacy -out example.pfx -inkey example.key -in example.crt
        # NOTE: -days is intentionally NOT passed here. `openssl req` ignores it
        # unless -x509 is also specified, and CSRs by design carry no validity
        # period; the issuing CA sets validity at signing time.
        # -newkey/-sha256 are emitted explicitly so the result is deterministic
        # even when a custom -ConfigFile omits default_bits/default_md.
        $keyoutPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName)
        $csrOutPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.csr' -f $fileName)
        $opensslArgs = @(
            'req', '-new', '-nodes',
            '-newkey', ('rsa:{0}' -f $KeySize),
            '-sha256',
            '-config', $configPath,
            '-keyout', $keyoutPath,
            '-out', $csrOutPath
        )

        # SHOULD PROCESS
        if ($PSCmdlet.ShouldProcess($OutputDirectory, "Create Files")) {

            # INVOKE OPENSSL
            [System.Void] (Invoke-OpenSsl -ArgumentList $opensslArgs)
        }
    }
}
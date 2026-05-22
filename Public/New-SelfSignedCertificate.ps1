function New-SelfSignedCertificate {
    <#
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
    .PARAMETER SubjectAlternativeName
        Subject Alternative Name (SAN)
    .PARAMETER KeySize
        RSA key size in bits (2048, 3072, or 4096; default is 4096). Emitted explicitly to openssl so the result is deterministic regardless of the config template contents.
    .INPUTS
        None.
    .OUTPUTS
        None. Writes three files into -OutputDirectory:
          <CN>.pem          - the self-signed certificate
          <CN>_PRIVATE.key  - the matching private key (unencrypted)
          <CN>.conf         - the openssl req config used to produce them,
                              preserved as a reproducible record of the
                              inputs. Only written when the cmdlet is invoked
                              in the __input parameter set; -ConfigFile mode
                              leaves the caller's file alone.
    .EXAMPLE
        PS C:\> New-SelfSignedCertificate -CommonName myDomain.com
        Generates a new self-signed certificate for myDomain.com
    .NOTES
        Name:      New-SelfSignedCertificate
        Author:    Justin Johns
        Version:   0.3.0 | Last Edit: 2026-05-22
        - Version history is captured in repository commit history
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = '__conf')]
    Param(
        [Parameter(HelpMessage = 'Output directory for generated files')]
        [ValidateScript({ Test-OutputDirectoryPath -Path $_ })]
        [System.String] $OutputDirectory = "$HOME\Desktop",

        [Parameter(HelpMessage = 'Validity period in days (default is 365)')]
        [ValidateRange(30, 3650)]
        [System.String] $Days = 365,

        [Parameter(Mandatory, ParameterSetName = '__conf', HelpMessage = 'Path to configuration template')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include '*.conf' })]
        [System.String] $ConfigFile,

        [Parameter(Mandatory, ParameterSetName = '__input', HelpMessage = 'Common Name (CN)')]
        [Alias('CN')]
        [ValidatePattern('^[\w\.-]+$')] # '^[\w\.-]+\.(com|org|gov|internal|local)$'
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
        [ValidatePattern('^[\w\.-]+\.(com|org|gov|info)$')]
        [System.String[]] $SubjectAlternativeName,

        [Parameter(HelpMessage = 'RSA key size in bits (default 4096)')]
        [ValidateSet(2048, 3072, 4096)]
        [System.Int32] $KeySize = 4096
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
        Write-Verbose -Message ('Parameter Set: {0}' -f $PSCmdlet.ParameterSetName)

        # CREATE OUTPUT DIRECTORY
        Initialize-OutputDirectory -Path $OutputDirectory

        # CREATE TEMPLATE FILE
        if ($PSCmdlet.ParameterSetName -eq '__input') {
            # CN is the source of truth for the artifact basename, so derive it
            # here rather than reading it back from the rendered .conf.
            $fileName = $CommonName

            # THE CHARACTER "*" IS NOT VALID IN A WINDOWS FILENAME. REPLACE "*" WITH "STAR"
            if ($fileName -match '\*') { $fileName = $fileName.Replace('*', 'star') }

            # The .conf is intentionally preserved alongside the .pem / .key
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
        # openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365
        # -newkey/-sha256 are emitted explicitly so output is deterministic
        # even when a custom -ConfigFile omits default_bits/default_md.
        $keyoutPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}_PRIVATE.key' -f $fileName)
        $certOutPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.pem' -f $fileName)
        $opensslArgs = @(
            'req', '-new', '-x509', '-nodes',
            '-newkey', ('rsa:{0}' -f $KeySize),
            '-sha256',
            '-days', $Days.ToString(),
            '-config', $configPath,
            '-keyout', $keyoutPath,
            '-out', $certOutPath
        )

        # SHOULD PROCESS
        if ($PSCmdlet.ShouldProcess($OutputDirectory, "Create Files")) {

            # GENERATE CERTIFICATE FILES USING OPENSSL
            [System.Void] (Invoke-OpenSsl -ArgumentList $opensslArgs)
        }
    }
}
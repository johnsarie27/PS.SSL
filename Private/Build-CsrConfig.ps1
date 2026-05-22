function Build-CsrConfig {
    <#
    .SYNOPSIS
        Render the module's CSR_Template into an openssl req config file.
    .DESCRIPTION
        Internal helper shared by New-CertificateSigningRequest and
        New-SelfSignedCertificate. Takes the same subject fields the public
        functions accept, drops the template lines whose tokens were not
        supplied, applies any Subject Alternative Names, performs token
        substitution, and writes the result to -OutputPath.

        The rendered .conf is intentionally preserved on disk (next to the
        cert / CSR / key it produced) so callers have a reproducible record
        of the inputs used to generate the request.
    .PARAMETER OutputPath
        Full path (including filename) where the rendered .conf will be
        written. The caller chooses the path; the helper does not pick the
        directory or filename so the public functions remain in control of
        their artifact-naming convention.
    .PARAMETER CommonName
        Common Name (CN). Always required because CN has no fallback line
        in the template - it must be substituted, not removed.
    .PARAMETER Country
        Country Name (C). Optional - omitted callers get the C = line removed.
    .PARAMETER State
        State or Province Name (ST). Optional.
    .PARAMETER Locality
        Locality Name (L). Optional.
    .PARAMETER Organization
        Organization Name (O). Optional.
    .PARAMETER OrganizationalUnit
        Organizational Unit Name (OU). Optional.
    .PARAMETER Email
        Email address. Optional.
    .PARAMETER SubjectAlternativeName
        Subject Alternative Name (SAN) entries. When omitted, the [alt_names]
        section and the subjectAltName = @alt_names directive are stripped.
    .INPUTS
        None.
    .OUTPUTS
        None. Writes the rendered config to -OutputPath as a side effect.
    .EXAMPLE
        PS C:\> Build-CsrConfig -CommonName www.example.com -OutputPath C:\out\www.example.com.conf -Organization Contoso
    .NOTES
        Name:      Build-CsrConfig
        Author:    Justin Johns
        - Reads the module-scoped $CSR_Template variable defined in PS.SSL.psm1.
        - The token-substitution behavior is preserved verbatim from the
          original inline implementations in the two public callers, so this
          helper is a refactor with no semantic change.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [System.String] $OutputPath,

        [Parameter(Mandatory)]
        [System.String] $CommonName,

        [Parameter()]
        [System.String] $Country,

        [Parameter()]
        [System.String] $State,

        [Parameter()]
        [System.String] $Locality,

        [Parameter()]
        [System.String] $Organization,

        [Parameter()]
        [System.String] $OrganizationalUnit,

        [Parameter()]
        [System.String] $Email,

        [Parameter()]
        [System.String[]] $SubjectAlternativeName
    )
    Process {
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

        # Preserved intentionally as a record of the settings used to
        # generate the sibling .csr / .key / .pem artifacts. Do not
        # treat this file as a temp file - callers depend on it staying.
        Set-Content -Path $OutputPath -Value $template -Confirm:$false

        Write-Verbose -Message ('Template file path: [{0}]' -f $OutputPath)
    }
}

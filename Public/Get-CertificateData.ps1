function Get-CertificateData {
    <#
    .SYNOPSIS
        Load an x509 certificate file as a .NET X509Certificate2 object.
    .DESCRIPTION
        Reads a certificate file (.crt, .cer, or .pem) and returns the
        corresponding System.Security.Cryptography.X509Certificates.X509Certificate2
        instance so callers can inspect Subject, Issuer, validity dates,
        extensions (incl. SAN), and the public key directly as typed members
        rather than scraping openssl's human-readable text output.

        openssl is invoked once to normalize the input encoding to DER bytes
        regardless of source format; the certificate is then constructed from
        those bytes via the standard .NET ctor.
    .PARAMETER Path
        Path to an x509 certificate file. Accepted extensions: .crt, .cer, .pem.
    .INPUTS
        System.String. Pipe a file path.
    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2.
    .EXAMPLE
        PS C:\> Get-CertificateData -Path .\example.pem | Select-Object Subject, NotAfter, Thumbprint
        Inspect summary fields.
    .EXAMPLE
        PS C:\> (Get-CertificateData -Path .\example.pem).Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | ForEach-Object { $_.Format($true) }
        Print the Subject Alternative Name extension in human-readable form.
    .EXAMPLE
        PS C:\> Get-CertificateData -Path .\fullchain.pem | Select-Object Subject
        Enumerate all certificates in a PEM bundle (leaf + intermediates + root).
    .EXAMPLE
        PS C:\> (Get-CertificateData -Path .\fullchain.pem).Count
        Returns the number of certificates in the bundle.
    .NOTES
        Status: Beta
        - PEM bundles containing multiple concatenated certificates (e.g.
          fullchain.pem) are fully enumerated: one X509Certificate2 object
          is emitted per BEGIN CERTIFICATE block. Wrap in @(...) if you need
          array semantics when the file may contain only one certificate.
        - DER-encoded files (.crt, .cer) and single-certificate PEM files
          each emit exactly one object, preserving prior behavior.
        - openssl is used solely as a format-normalizer here; .NET's PEM
          file loaders (X509Certificate2.CreateFromPemFile) require .NET 5+
          and the module manifest declares PS 7.0 / .NET Core 3.1.
        - BREAKING CHANGE from prior versions: this function returned the
          raw multi-line openssl text dump. It now returns a typed cert
          object. Pipe through `Format-List *` for a comparable human view.
    #>
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to x509 certificate file')]
        [ValidateScript({
                if (-not (Test-Path -Path $_ -PathType Leaf)) {
                    Write-Error -Message ('File not found: {0}' -f $_) -ErrorAction Stop
                }
                $ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
                if ($ext -notin '.crt', '.cer', '.pem') {
                    Write-Error -Message ('Unsupported extension [{0}]. Expected .crt, .cer, or .pem.' -f $ext) -ErrorAction Stop
                }
                $true
            })]
        [System.String] $Path
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # SCAN FOR PEM CERTIFICATE BLOCKS — HANDLES SINGLE-CERT FILES AND BUNDLES.
        # ReadAllText IS USED OVER Get-Content -Raw BECAUSE THE LATTER RETURNS $null
        # FOR EMPTY FILES, WHICH WOULD CAUSE Regex::Matches TO THROW.
        $pemPattern = '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----'
        $blocks = [System.Text.RegularExpressions.Regex]::Matches(
            [System.IO.File]::ReadAllText($Path), $pemPattern)

        if ($blocks.Count -le 1) {
            # SINGLE CERT OR DER FORMAT — ORIGINAL BEHAVIOR PRESERVED
            $derPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('pssl-cert-{0}.der' -f (New-Guid).ToString().Substring(0, 8))
            try {
                [System.Void] (Invoke-OpenSsl -ArgumentList @('x509', '-in', $Path, '-outform', 'DER', '-out', $derPath))
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                    (Get-Content -Path $derPath -AsByteStream -Raw))
            }
            finally {
                if (Test-Path -Path $derPath) { Remove-Item -Path $derPath -Force -ErrorAction Ignore }
            }
        }
        else {
            # PEM BUNDLE — EMIT ONE X509Certificate2 PER BLOCK TO THE PIPELINE
            Write-Verbose -Message ('Found [{0}] certificates in [{1}]' -f $blocks.Count, $Path)
            foreach ($block in $blocks) {
                $tempPem = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('pssl-cert-{0}.pem' -f (New-Guid).ToString().Substring(0, 8))
                $derPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('pssl-cert-{0}.der' -f (New-Guid).ToString().Substring(0, 8))
                try {
                    Set-Content -Path $tempPem -Value $block.Value -Encoding ASCII -NoNewline
                    [System.Void] (Invoke-OpenSsl -ArgumentList @('x509', '-in', $tempPem, '-outform', 'DER', '-out', $derPath))
                    [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                        (Get-Content -Path $derPath -AsByteStream -Raw))
                }
                finally {
                    if (Test-Path -Path $tempPem) { Remove-Item -Path $tempPem -Force -ErrorAction Ignore }
                    if (Test-Path -Path $derPath) { Remove-Item -Path $derPath -Force -ErrorAction Ignore }
                }
            }
        }
    }
}

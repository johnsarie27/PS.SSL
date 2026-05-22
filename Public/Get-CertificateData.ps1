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
    .NOTES
        Name:      Get-CertificateData
        Author:    Justin Johns
        - PEM files containing multiple concatenated certificates (e.g.
          fullchain.pem) are reduced to the FIRST certificate only. This
          matches the previous behavior of `openssl x509 -text -noout`.
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
                if (-not (Test-Path -Path $_ -PathType Leaf)) { Write-Error -Message "File not found: $_" -ErrorAction Stop }
                $ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
                if ($ext -notin '.crt', '.cer', '.pem') {
                    Write-Error -Message "Unsupported extension '$ext'. Expected .crt, .cer, or .pem." -ErrorAction Stop
                }
                $true
            })]
        [System.String] $Path
    )
    Process {
        # Normalize PEM/CRT/CER input to DER bytes via openssl. We write to a
        # temp file rather than capturing DER bytes from stdout because the
        # Invoke-OpenSsl helper captures StdOut as a string, which would
        # corrupt binary content.
        $derPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('pssl-cert-{0}.der' -f [System.Guid]::NewGuid().Guid.Substring(0, 8))
        try {
            $sslParams = @{
                ArgumentList = @('x509', '-in', $Path, '-outform', 'DER', '-out', $derPath)
            }
            [System.Void] (Invoke-OpenSsl @sslParams)

            $bytes = [System.IO.File]::ReadAllBytes($derPath)
            [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
        }
        finally {
            if (Test-Path -Path $derPath) { Remove-Item -Path $derPath -Force -ErrorAction SilentlyContinue }
        }
    }
}
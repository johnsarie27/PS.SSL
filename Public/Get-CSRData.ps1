function Get-CSRData {
    <#
    .SYNOPSIS
        Parse and verify a certificate signing request (CSR).
    .DESCRIPTION
        Calls `openssl req -text -noout -verify` on the given CSR file, parses
        the human-readable output, and returns a structured PSCustomObject
        with the most commonly-inspected fields plus the full raw text.

        The verification result (openssl's "Certificate request self-signature
        verify OK" / "Signature did not match" message, written to stderr) is
        surfaced as a boolean property. Verification failure does NOT
        terminate the function so callers can report on invalid CSRs too.
    .PARAMETER Path
        Path to a certificate signing request (.csr) file. Accepts the legacy
        alias -CSR.
    .INPUTS
        System.String. Pipe a file path.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with properties:
          Path, Subject, PublicKeyAlgorithm, PublicKeyBits,
          SignatureAlgorithm, SubjectAlternativeName, Verified, Raw.
    .EXAMPLE
        PS C:\> Get-CSRData -Path .\example.csr | Select-Object Subject, Verified
        Inspect summary fields.
    .EXAMPLE
        PS C:\> (Get-CSRData -Path .\example.csr).Raw
        Print the full openssl -text dump (preserves the pre-3a output format
        for callers that want the original visual review experience).
    .NOTES
        Name:      Get-CSRData
        Author:    Justin Johns
        - Field extraction is regex-based against openssl's human output
          because no public .NET CSR-loader exists at PS 7.0 / .NET Core 3.1
          (CertificateRequest.LoadSigningRequest is .NET 7+). Unmatched
          fields become $null rather than throwing.
        - BREAKING CHANGE from prior versions: this function returned the
          raw multi-line openssl text dump. It now returns a structured
          object; the original text is preserved on the .Raw property.
    #>
    [OutputType([System.Management.Automation.PSCustomObject])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to CA-signed certificate request')]
        [ValidateScript({
                if (-not (Test-Path -Path $_ -PathType Leaf)) { Write-Error -Message "File not found: $_" -ErrorAction Stop }
                $ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
                if ($ext -ne '.csr') { Write-Error -Message "Unsupported extension '$ext'. Expected .csr." -ErrorAction Stop }
                $true
            })]
        [Alias('CSR')]
        [System.String] $Path
    )
    Process {
        # openssl req -text -noout -verify -in <csr>
        # -IgnoreExitCode: a verification failure should produce a structured
        # object with Verified=$false, not terminate.
        $sslParams = @{
            ArgumentList    = @('req', '-text', '-noout', '-verify', '-in', $Path)
            IgnoreExitCode  = $true
        }
        $result = Invoke-OpenSsl @sslParams

        $text = if ($result.StdOut) { $result.StdOut } else { '' }

        # Subject: e.g. "        Subject: C = US, ST = California, ..., CN = example.com"
        $subject = $null
        if ($text -match '(?m)^\s*Subject:\s*(.+?)\s*$') { $subject = $Matches[1] }

        # Public-Key: e.g. "                Public-Key: (4096 bit)"
        $publicKeyBits = $null
        if ($text -match '(?m)^\s*Public-Key:\s*\((\d+)\s*bit\)') { $publicKeyBits = [int] $Matches[1] }

        # Public Key Algorithm: e.g. "            Public Key Algorithm: rsaEncryption"
        $publicKeyAlgorithm = $null
        if ($text -match '(?m)^\s*Public Key Algorithm:\s*(.+?)\s*$') { $publicKeyAlgorithm = $Matches[1] }

        # Signature Algorithm appears twice in CSR -text output (once inside
        # the SubjectPublicKeyInfo block, once at the request-signature
        # block). The LAST occurrence is the algorithm used to sign the
        # request, which is what callers actually care about.
        $signatureAlgorithm = $null
        $sigMatches = [regex]::Matches($text, '(?m)^\s*Signature Algorithm:\s*(.+?)\s*$')
        if ($sigMatches.Count -gt 0) {
            $signatureAlgorithm = $sigMatches[$sigMatches.Count - 1].Groups[1].Value
        }

        # SANs appear on the line immediately following the header:
        #     X509v3 Subject Alternative Name:
        #         DNS:a.example.com, DNS:b.example.com
        $sans = @()
        if ($text -match 'X509v3 Subject Alternative Name:\s*[\r\n]+\s*([^\r\n]+)') {
            $sans = @(
                $Matches[1] -split ',\s*' | ForEach-Object {
                    if ($_ -match '^\s*DNS:(.+)$') { $Matches[1].Trim() } else { $_.Trim() }
                } | Where-Object { $_ }
            )
        }

        # openssl's verify message is written to STDOUT (not stderr) in
        # 1.1.x, 3.x, and 4.x. Tolerate both the verbose 3.x/4.x wording
        # ("Certificate request self-signature verify OK") and the older
        # 1.1.x phrasing ("verify OK").
        $verified = ($text -match 'self-signature verify OK' -or $text -match '(?m)^\s*verify OK\s*$')

        [PSCustomObject] @{
            Path                   = $Path
            Subject                = $subject
            PublicKeyAlgorithm     = $publicKeyAlgorithm
            PublicKeyBits          = $publicKeyBits
            SignatureAlgorithm     = $signatureAlgorithm
            SubjectAlternativeName = $sans
            Verified               = $verified
            Raw                    = $text
        }
    }
}
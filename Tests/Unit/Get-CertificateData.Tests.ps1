BeforeAll {
    $manifestPath = if ($env:BHPSModuleManifest) {
        $env:BHPSModuleManifest
    }
    else {
        Join-Path -Path $PSScriptRoot -ChildPath '..\..\PS.SSL.psd1' | Resolve-Path | Select-Object -ExpandProperty Path
    }
    Get-Module -Name 'PS.SSL' -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $manifestPath -Force

    # Generate in-memory self-signed certs for fixture use. We create three so
    # that multi-cert bundle tests can verify count and individual thumbprints.
    function New-FixtureCert ([string] $Subject) {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        try {
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                "CN=$Subject", $rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $req.CreateSelfSigned([datetimeoffset]::UtcNow.AddDays(-1), [datetimeoffset]::UtcNow.AddDays(30))
        }
        finally { $rsa.Dispose() }
    }

    function ConvertTo-PemString ([byte[]] $der) {
        $b64 = [System.Convert]::ToBase64String($der, [System.Base64FormattingOptions]::InsertLineBreaks)
        "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----"
    }

    $cert1 = New-FixtureCert 'PSSL Unit Test'
    $cert2 = New-FixtureCert 'PSSL Intermediate CA'
    $cert3 = New-FixtureCert 'PSSL Root CA'

    $script:fixtureDer         = $cert1.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $script:fixtureDer2        = $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $script:fixtureDer3        = $cert3.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $script:fixtureThumbprint  = $cert1.Thumbprint
    $script:fixtureThumbprint2 = $cert2.Thumbprint
    $script:fixtureThumbprint3 = $cert3.Thumbprint

    # Three-cert PEM bundle (leaf + intermediate + root) used in bundle tests.
    $script:bundlePem = (ConvertTo-PemString $script:fixtureDer) + "`n" +
                        (ConvertTo-PemString $script:fixtureDer2) + "`n" +
                        (ConvertTo-PemString $script:fixtureDer3)

    # Ordered DER bytes for the bundle, used by the stateful mock below.
    $script:bundleDerBytes = @($script:fixtureDer, $script:fixtureDer2, $script:fixtureDer3)
}

Describe 'Get-CertificateData' {

    BeforeEach {
        # Mock the module-private openssl boundary. Get-CertificateData
        # writes its DER output via `openssl x509 -outform DER -out <path>`
        # then reads that file back. The mock locates the `-out` argument
        # and writes the in-memory fixture DER bytes to that path.
        Mock -ModuleName PS.SSL Invoke-OpenSsl {
            $outIndex = [System.Array]::IndexOf($ArgumentList, '-out')
            if ($outIndex -ge 0 -and $outIndex + 1 -lt $ArgumentList.Length) {
                $outPath = $ArgumentList[$outIndex + 1]
                [System.IO.File]::WriteAllBytes($outPath, $script:fixtureDer)
            }
            [PSCustomObject] @{ ExitCode = 0; StdOut = ''; StdErr = '' }
        }
    }

    Context 'Parameter validation' {

        It 'Rejects a path that does not exist' {
            $missing = Join-Path $TestDrive 'does-not-exist.pem'
            { Get-CertificateData -Path $missing } | Should -Throw
        }

        It 'Rejects a path with an unsupported extension' {
            $bad = Join-Path $TestDrive 'cert.txt'
            Set-Content -Path $bad -Value 'placeholder'
            { Get-CertificateData -Path $bad } | Should -Throw
        }

        It 'Accepts .pem, .crt, and .cer extensions' {
            foreach ($ext in '.pem', '.crt', '.cer') {
                $path = Join-Path $TestDrive ('cert{0}' -f $ext)
                Set-Content -Path $path -Value 'placeholder'
                { Get-CertificateData -Path $path } | Should -Not -Throw
            }
        }
    }

    Context 'OpenSSL invocation' {

        BeforeEach {
            $script:certPath = Join-Path $TestDrive 'cert.pem'
            Set-Content -Path $script:certPath -Value 'placeholder'
        }

        It 'Invokes openssl x509 with -outform DER' {
            Get-CertificateData -Path $script:certPath | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                ($ArgumentList -contains 'x509')    -and
                ($ArgumentList -contains '-in')     -and
                ($ArgumentList -contains '-outform')-and
                ($ArgumentList -contains 'DER')     -and
                ($ArgumentList -contains '-out')
            }
        }

        It 'Passes the input file path to openssl via -in for a single-cert file' {
            Get-CertificateData -Path $script:certPath | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $inIndex = [System.Array]::IndexOf($ArgumentList, '-in')
                $inIndex -ge 0 -and $ArgumentList[$inIndex + 1] -eq $script:certPath
            }
        }
    }

    Context 'Return type — single certificate' {

        BeforeEach {
            $script:certPath = Join-Path $TestDrive 'cert.pem'
            Set-Content -Path $script:certPath -Value 'placeholder'
        }

        It 'Returns an X509Certificate2 instance' {
            $result = Get-CertificateData -Path $script:certPath
            $result | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Certificate2])
        }

        It 'Returns the certificate constructed from openssl-normalized DER bytes' {
            $result = Get-CertificateData -Path $script:certPath
            $result.Thumbprint | Should -Be $script:fixtureThumbprint
            $result.Subject    | Should -Match 'PSSL Unit Test'
        }

        It 'Cleans up the temporary DER file after constructing the certificate' {
            $tempBefore = Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.der' -ErrorAction SilentlyContinue
            Get-CertificateData -Path $script:certPath | Out-Null
            $tempAfter = Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.der' -ErrorAction SilentlyContinue
            $tempAfter.Count | Should -Be $tempBefore.Count
        }
    }

    Context 'Multi-certificate PEM bundle' {

        BeforeEach {
            $script:bundlePath = Join-Path $TestDrive 'fullchain.pem'
            Set-Content -Path $script:bundlePath -Value $script:bundlePem

            # Stateful mock: each call writes the next cert's DER bytes so the
            # returned objects reflect the correct per-block fixture thumbprints.
            $script:mockCallIndex = 0
            Mock -ModuleName PS.SSL Invoke-OpenSsl {
                $outIndex = [System.Array]::IndexOf($ArgumentList, '-out')
                if ($outIndex -ge 0 -and $outIndex + 1 -lt $ArgumentList.Length) {
                    $outPath = $ArgumentList[$outIndex + 1]
                    [System.IO.File]::WriteAllBytes($outPath, $script:bundleDerBytes[$script:mockCallIndex])
                }
                $script:mockCallIndex++
                [PSCustomObject] @{ ExitCode = 0; StdOut = ''; StdErr = '' }
            }
        }

        It 'Returns 3 X509Certificate2 objects for a 3-cert bundle' {
            $results = @(Get-CertificateData -Path $script:bundlePath)
            $results.Count | Should -Be 3
        }

        It 'Each returned object is an X509Certificate2 instance' {
            $results = @(Get-CertificateData -Path $script:bundlePath)
            foreach ($r in $results) {
                $r | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Certificate2])
            }
        }

        It 'Invokes openssl once per certificate block' {
            Get-CertificateData -Path $script:bundlePath | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 3 -Exactly
        }

        It 'Returns certificates in bundle order' {
            $results = @(Get-CertificateData -Path $script:bundlePath)
            $results[0].Thumbprint | Should -Be $script:fixtureThumbprint
            $results[1].Thumbprint | Should -Be $script:fixtureThumbprint2
            $results[2].Thumbprint | Should -Be $script:fixtureThumbprint3
        }

        It 'Cleans up all temporary PEM and DER files after processing the bundle' {
            $derBefore = @(Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.der'  -ErrorAction SilentlyContinue)
            $pemBefore = @(Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.pem'  -ErrorAction SilentlyContinue)
            Get-CertificateData -Path $script:bundlePath | Out-Null
            $derAfter  = @(Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.der'  -ErrorAction SilentlyContinue)
            $pemAfter  = @(Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'pssl-cert-*.pem'  -ErrorAction SilentlyContinue)
            $derAfter.Count | Should -Be $derBefore.Count
            $pemAfter.Count | Should -Be $pemBefore.Count
        }
    }
}

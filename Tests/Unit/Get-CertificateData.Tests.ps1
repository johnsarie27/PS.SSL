BeforeAll {
    $manifestPath = if ($env:BHPSModuleManifest) {
        $env:BHPSModuleManifest
    }
    else {
        Join-Path -Path $PSScriptRoot -ChildPath '..\..\PS.SSL.psd1' | Resolve-Path | Select-Object -ExpandProperty Path
    }
    Get-Module -Name 'PS.SSL' -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $manifestPath -Force

    # A minimal valid DER blob that .NET X509Certificate2::new() will accept
    # would still need to be a real cert. To avoid bundling a binary fixture,
    # we generate a self-signed cert in-memory with .NET, export to DER, and
    # have the mocked Invoke-OpenSsl write those bytes to the temp DER path.
    $rsa = [System.Security.Cryptography.RSA]::Create(2048)
    try {
        $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=PSSL Unit Test',
            $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $cert = $req.CreateSelfSigned([datetimeoffset]::UtcNow.AddDays(-1), [datetimeoffset]::UtcNow.AddDays(30))
        $script:fixtureDer  = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $script:fixtureThumbprint = $cert.Thumbprint
    }
    finally {
        $rsa.Dispose()
    }
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

        It 'Passes the input file path to openssl via -in' {
            Get-CertificateData -Path $script:certPath | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $inIndex = [System.Array]::IndexOf($ArgumentList, '-in')
                $inIndex -ge 0 -and $ArgumentList[$inIndex + 1] -eq $script:certPath
            }
        }
    }

    Context 'Return type' {

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
}

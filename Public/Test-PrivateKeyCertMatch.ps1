function Test-PrivateKeyCertMatch {
    <#
    .SYNOPSIS
        Test if private key matches certificate
    .DESCRIPTION
        Test if a given private key is associated with a given certificate by
        comparing the public key hashes extracted from both files using openssl
    .PARAMETER CertificatePath
        Path to certificate file (.pem, .crt, .cer)
    .PARAMETER PrivateKeyPath
        Path to private key file (.key, .pem)
    .INPUTS
        System.String.
    .OUTPUTS
        System.Boolean.
    .EXAMPLE
        PS C:\> Test-PrivateKeyCertMatch -PrivateKeyPath .\private.key -CertificatePath .\cert.pem
        Tests if the private key matches the certificate and returns True if they match
    .EXAMPLE
        PS C:\> Test-PrivateKeyCertMatch -CertificatePath .\cert.crt -PrivateKeyPath .\key.pem -Verbose
        Tests if the private key matches the certificate with verbose output showing the hashes
    .EXAMPLE
        PS C:\> Test-PrivateKeyCertMatch .\private.key .\cert.pem
        Tests without explicit parameter names
    .EXAMPLE
        PS C:\> Get-ChildItem .\*.cer | Where-Object { Test-PrivateKeyCertMatch -PrivateKeyPath .\private.key -CertificatePath $_.FullName }
        Tests multiple certificates against a single private key and returns only the matching certificate file
    .EXAMPLE
        PS C:\> Get-ChildItem .\*.key | Where-Object { Test-PrivateKeyCertMatch -PrivateKeyPath $_.FullName -CertificatePath .\cert.pem }
        Tests multiple private keys against a single certificate and returns only the matching key file
    .EXAMPLE
        PS C:> $cn = "test.example.com"
        PS C:> $otherCn = "other.example.com"
        PS C:> $outDir = "$HOME\Desktop"
        PS C:> New-SelfSignedCertificate -CommonName $cn -OutputDirectory $outDir -Confirm:$false
        PS C:> New-SelfSignedCertificate -CommonName $otherCn -OutputDirectory $outDir -Confirm:$false
        PS C:> Test-PrivateKeyCertMatch -PrivateKeyPath "$outDir\${cn}_PRIVATE.key" -CertificatePath "$outDir\$cn.pem"
        PS C:> Test-PrivateKeyCertMatch -PrivateKeyPath "$outDir\${cn}_PRIVATE.key" -CertificatePath "$outDir\$otherCn.pem"
        Generates two self-signed certificates and tests the private key of the first against both. Only the first test should return True.
    .NOTES
        General notes
        https://man.openbsd.org/openssl.1
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Path to private key file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.key", "*.pem" })]
        [System.String] $PrivateKeyPath,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, HelpMessage = 'Path to certificate file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.crt", "*.cer", "*.pem" })]
        [System.String] $CertificatePath
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }
    Process {
        try {
            # CREATE TEMPORARY FILES
            $keyTempFile = (New-TemporaryFile).FullName
            $certTempFile = (New-TemporaryFile).FullName

            # EXTRACT PUBLIC KEY FROM PRIVATE KEY
            $keyParams = @{
                FilePath               = 'openssl'
                ArgumentList           = @(
                    'pkey -pubout'
                    '-in {0}' -f $PrivateKeyPath
                )
                RedirectStandardOutput = $keyTempFile
                Wait                   = $true
                NoNewWindow            = $true
                PassThru               = $true
            }
            $keyProc = Start-Process @keyParams

            # VALIDATE KEY EXTRACTION
            if ($keyProc.ExitCode -NE 0) {
                Write-Error -Message ('openssl failed to extract public key from private key with exit code: {0}' -f $keyProc.ExitCode)
                return $false
            }

            # HASH THE PRIVATE KEY PUBLIC KEY
            $keyHash = (Get-FileHash -Path $keyTempFile -Algorithm SHA256).Hash
            Write-Verbose -Message ('Private key public key hash: {0}' -f $keyHash)

            # EXTRACT PUBLIC KEY FROM CERTIFICATE
            $certParams = @{
                FilePath               = 'openssl'
                ArgumentList           = @(
                    'x509 -noout -pubkey'
                    '-in {0}' -f $CertificatePath
                )
                RedirectStandardOutput = $certTempFile
                Wait                   = $true
                NoNewWindow            = $true
                PassThru               = $true
            }
            $certProc = Start-Process @certParams

            # VALIDATE CERTIFICATE EXTRACTION
            if ($certProc.ExitCode -NE 0) {
                Write-Error -Message ('openssl failed to extract public key from certificate with exit code: {0}' -f $certProc.ExitCode)
                return $false
            }

            # HASH THE CERTIFICATE PUBLIC KEY
            $certHash = (Get-FileHash -Path $certTempFile -Algorithm SHA256).Hash
            Write-Verbose -Message ('Certificate public key hash: {0}' -f $certHash)

            # COMPARE HASHES
            $match = $certHash -eq $keyHash

            # OUTPUT RESULT
            if ($match) {
                Write-Verbose -Message 'Private key matches certificate'
            }
            else {
                Write-Verbose -Message 'Private key does NOT match certificate'
            }

            return $match
        }
        catch {
            Write-Error -Message ('Error testing key-certificate match: {0}' -f $_.Exception.Message)
            return $false
        }
        finally {
            # CLEANUP TEMPORARY FILES
            Remove-Item -Path $keyTempFile, $certTempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

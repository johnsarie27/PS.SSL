BeforeAll {
    $manifestPath = if ($env:BHPSModuleManifest) {
        $env:BHPSModuleManifest
    }
    else {
        Join-Path -Path $PSScriptRoot -ChildPath '..\..\PS.SSL.psd1' | Resolve-Path | Select-Object -ExpandProperty Path
    }
    Get-Module -Name 'PS.SSL' -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $manifestPath -Force

    # Indirect the test target through a variable so PSScriptAnalyzer's
    # PSAvoidUsingComputerNameHardcoded rule does not fire on test code
    # that never reaches a real network endpoint (Invoke-OpenSsl is mocked).
    $script:testHost = 'example.com'
}

Describe 'Test-Protocol' {

    BeforeEach {
        Mock -ModuleName PS.SSL Invoke-OpenSsl {
            [PSCustomObject] @{ ExitCode = 0; StdOut = 'handshake ok'; StdErr = '' }
        }
    }

    Context 'Parameter validation' {

        It 'Rejects an empty ComputerName' {
            { Test-Protocol -ComputerName ([string]::Empty) -Protocol 'TLS 1.2' } | Should -Throw
        }

        It 'Rejects an out-of-range Port' {
            { Test-Protocol -ComputerName $script:testHost -Port 70000 -Protocol 'TLS 1.2' } | Should -Throw
        }

        It 'Rejects a Protocol value not in the ValidateSet' {
            { Test-Protocol -ComputerName $script:testHost -Protocol 'SSLv3' } | Should -Throw
        }
    }

    Context 'OpenSSL invocation' {

        It 'Calls openssl s_client with -connect host:port' {
            Test-Protocol -ComputerName $script:testHost -Port 443 -Protocol 'TLS 1.2' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                ($ArgumentList -contains 's_client') -and
                ($ArgumentList -contains '-connect')
            }
        }

        It 'Forms the -connect endpoint as host:port' {
            Test-Protocol -ComputerName $script:testHost -Port 8443 -Protocol 'TLS 1.2' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $connectIndex = [System.Array]::IndexOf($ArgumentList, '-connect')
                $connectIndex -ge 0 -and $ArgumentList[$connectIndex + 1] -eq 'example.com:8443'
            }
        }

        It 'Defaults to port 443 when -Port is not supplied' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.2' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $connectIndex = [System.Array]::IndexOf($ArgumentList, '-connect')
                $connectIndex -ge 0 -and $ArgumentList[$connectIndex + 1] -eq 'example.com:443'
            }
        }

        It 'Uses -IgnoreExitCode so a rejected protocol is non-terminating' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.2' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $IgnoreExitCode -eq $true
            }
        }

        It 'Maps "TLS 1.0" to the -tls1 switch' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.0' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '-tls1'
            }
        }

        It 'Maps "TLS 1.1" to the -tls1_1 switch' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.1' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '-tls1_1'
            }
        }

        It 'Maps "TLS 1.2" to the -tls1_2 switch' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.2' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '-tls1_2'
            }
        }

        It 'Maps "TLS 1.3" to the -tls1_3 switch' {
            Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.3' | Out-Null
            Should -Invoke -ModuleName PS.SSL -CommandName 'Invoke-OpenSsl' -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '-tls1_3'
            }
        }
    }

    Context 'Structured output contract' {

        It 'Returns a PSCustomObject with the full property set' {
            $result = Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.2'
            $result | Should -BeOfType ([pscustomobject])
            foreach ($prop in 'ComputerName', 'Port', 'Protocol', 'Supported', 'Error') {
                $result.PSObject.Properties.Name | Should -Contain $prop
            }
        }

        It 'Sets Supported=$true and Error=$null on ExitCode 0' {
            $result = Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.2'
            $result.Supported | Should -BeTrue
            $result.Error     | Should -BeNullOrEmpty
        }

        It 'Sets Supported=$false and surfaces trimmed stderr on non-zero exit' {
            Mock -ModuleName PS.SSL Invoke-OpenSsl {
                [PSCustomObject] @{ ExitCode = 1; StdOut = ''; StdErr = "  no protocols available  `n" }
            }
            $result = Test-Protocol -ComputerName $script:testHost -Protocol 'TLS 1.0'
            $result.Supported | Should -BeFalse
            $result.Error     | Should -Be 'no protocols available'
        }

        It 'Echoes ComputerName, Port, and Protocol to the output object verbatim' {
            $result = Test-Protocol -ComputerName $script:testHost -Port 8443 -Protocol 'TLS 1.3'
            $result.ComputerName | Should -Be 'example.com'
            $result.Port         | Should -Be 8443
            $result.Protocol     | Should -Be 'TLS 1.3'
        }
    }
}

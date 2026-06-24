BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'PS.SSL module loader (Windows)' -Fixture {

    It -Name 'does not warn about missing openssl when openssl is on $env:Path' -Test {
        # windows-latest ships Git for Windows which adds C:\Program Files\Git\usr\bin
        # to $env:Path, where openssl.exe lives. If this assertion fails, the
        # runner image regressed and the integration suite will silently skip.
        $env:Path | Should -Match 'openssl|Git\\usr\\bin'
        Get-Module -Name $env:BHProjectName -All | Remove-Module -Force -ErrorAction 'SilentlyContinue'
        $warnings = @()
        Import-Module -Name $env:BHPSModuleManifest -Force -WarningVariable 'warnings' -WarningAction 'SilentlyContinue'
        ($warnings | Where-Object -FilterScript { $_ -match 'Openssl not found' }) | Should -BeNullOrEmpty
    }

    It -Name 'warns about missing openssl when openssl is absent from $env:Path' -Test {
        $originalPath = $env:Path
        try {
            $env:Path = ($env:Path -split ';' |
                Where-Object -FilterScript { $_ -notmatch 'openssl' -and $_ -notmatch 'Git\\usr\\bin' }) -join ';'
            Get-Module -Name $env:BHProjectName -All | Remove-Module -Force -ErrorAction 'SilentlyContinue'
            $warnings = @()
            Import-Module -Name $env:BHPSModuleManifest -Force -WarningVariable 'warnings' -WarningAction 'SilentlyContinue'
            ($warnings | Where-Object -FilterScript { $_ -match 'Openssl not found' }) | Should -Not -BeNullOrEmpty
        }
        finally {
            $env:Path = $originalPath
            Get-Module -Name $env:BHProjectName -All | Remove-Module -Force -ErrorAction 'SilentlyContinue'
            Import-Module -Name $env:BHPSModuleManifest -Force
        }
    }
}

function ConvertTo-Text {
    <# =========================================================================
    .SYNOPSIS
        Convert PFX file to plain text
    .DESCRIPTION
        Convert PFX file to plain text including private key
    .PARAMETER PFX
        Path to PFX file
    .PARAMETER OutputDirectory
        Path to plain text output directory
    .PARAMETER Password
        Password to PFX file
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> ConvertTo-Text -PFX .\myCert.pfx -OutputDirectory .\newFolder -Password $pw
        Converts myCert.pfx to myCert.txt exposing all certificate details in plain text
    .NOTES
        General notes
    ========================================================================= #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Path to PFX file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.pfx" })]
        [string] $PFX,

        [Parameter(HelpMessage = 'Output directory for CSR and key file')]
        [ValidateScript({ Test-Path -Path (Split-Path -Path $_) -PathType Container })]
        [string] $OutputDirectory = "$HOME\Desktop",

        [Parameter(Mandatory, HelpMessage = 'Password used to protect exported PFX file')]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString] $Password
    )
    Begin {
        # VALIDATE PASSWORD
        Get-PfxCertificate -FilePath $PFX -Password $Password -ErrorAction Stop | Out-Null

        # GET OUTPUT DIRECTORY
        if (-not (Test-Path -Path $OutputDirectory)) { New-Item -Path $OutputDirectory -ItemType Directory }
        Write-Verbose -Message ('Created new folder: {0}' -f $OutputDirectory)

        # SET OUTPUT FILE NAME
        $name = '{0}.txt' -f (Split-Path -Path $PFX -LeafBase)
        Write-Verbose -Message ('Set filename to: {0}' -f $name)

        # CREATE CREDENTIAL OBJECT WITH PASSWORD
        $creds = [System.Management.Automation.PSCredential]::new('UserName', $Password)
    }
    End {
        # VERIFY SIGNED CERTIFICATE
        # openssl pkcs12 -in <PFX_PATH> -out <FILE.TXT> -nodes
        $sslParams = @{
            FilePath     = 'openssl.exe'
            ArgumentList = @(
                'pkcs12'
                '-in {0}' -f $PFX
                '-out {0}' -f (Join-Path -Path $OutputDirectory -ChildPath $name)
                '-nodes'
                '-passin pass:{0}' -f $creds.GetNetworkCredential().Password
            )
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }
        $proc = Start-Process @sslParams

        if ($proc.ExitCode -NE 0) { Write-Error -Message ('openssl exited with code: {0}' -f $proc.ExitCode) }
    }
}
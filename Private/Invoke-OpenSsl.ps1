function Invoke-OpenSsl {
    <#
    .SYNOPSIS
        Invoke the openssl command-line tool and capture its output.
    .DESCRIPTION
        Centralized wrapper for openssl. Builds a System.Diagnostics.Process with
        stdout/stderr redirected so callers receive the result in any PowerShell
        host (including ISE, VSCode terminal, remoting sessions, and CI). On a
        non-zero exit code the function emits a terminating error unless
        -IgnoreExitCode is supplied (used by probing callers such as Test-Cipher
        and Test-Protocol where a non-zero exit is an expected outcome).
    .PARAMETER ArgumentList
        Arguments to pass to openssl. Each element is a discrete argv entry; do
        not pre-join into a single string and do not wrap values containing
        spaces in quotes. Quoting is handled by ProcessStartInfo.ArgumentList.
    .PARAMETER IgnoreExitCode
        Return the result object even when openssl exits non-zero. Callers must
        inspect the ExitCode property themselves.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with ExitCode, StdOut, StdErr.
    .EXAMPLE
        PS C:\> Invoke-OpenSsl -ArgumentList 'version'
        Runs 'openssl version' and returns a result object.
    .EXAMPLE
        PS C:\> $r = Invoke-OpenSsl -ArgumentList @('s_client', '-cipher', $c, '-connect', "$h`:443") -IgnoreExitCode
        PS C:\> if ($r.ExitCode -eq 0) { 'supported' } else { 'not supported' }
        Use -IgnoreExitCode for probing scenarios where a non-zero exit is meaningful, not fatal.
    .NOTES
        Name:      Invoke-OpenSsl
        Author:    Justin Johns
        Version:   0.1.0 | Last Edit: 2026-05-22
        - Version history is captured in repository commit history
        Internal helper. Not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Arguments to pass to openssl (argv-style array)')]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $ArgumentList,

        [Parameter(HelpMessage = 'Return non-zero exits as data instead of a terminating error')]
        [System.Management.Automation.SwitchParameter] $IgnoreExitCode
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"

        if (-not (Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Error -Message "'openssl' was not found on PATH." -Category ObjectNotFound -ErrorAction Stop
        }
    }
    Process {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName               = 'openssl'
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError  = $true
        $startInfo.UseShellExecute        = $false
        $startInfo.CreateNoWindow         = $true
        foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            [System.Void] $process.Start()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError  = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            $result = [PSCustomObject] @{
                ExitCode = $process.ExitCode
                StdOut   = $standardOutput
                StdErr   = $standardError
            }

            if ($process.ExitCode -ne 0 -and -not $IgnoreExitCode) {
                Write-Error -Message ("openssl exited with code {0}: {1}" -f $process.ExitCode, $standardError.Trim()) -Category InvalidResult -ErrorAction Stop
            }

            $result
        }
        finally {
            $process.Dispose()
        }
    }
}

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

        # FAIL FAST IF OPENSSL IS NOT ON PATH. THIS IS A TERMINATING ERROR
        # SO CALLERS DON'T NEED TO RE-CHECK; SURFACES A CLEAR DIAGNOSTIC
        # INSTEAD OF A CRYPTIC "FILE NOT FOUND" FROM Process.Start().
        if (-not (Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Error -Message "'openssl' was not found on PATH." -Category ObjectNotFound -ErrorAction Stop
        }
    }
    Process {
        # BUILD THE PROCESS START INFO. UseShellExecute=$false IS REQUIRED
        # IN ORDER TO REDIRECT STDOUT/STDERR; CreateNoWindow=$true SUPPRESSES
        # THE TRANSIENT CONSOLE WINDOW THAT OTHERWISE FLASHES ON WINDOWS.
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName               = 'openssl'
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError  = $true
        $startInfo.UseShellExecute        = $false
        $startInfo.CreateNoWindow         = $true

        # POPULATE ArgumentList ONE ENTRY AT A TIME. PowerShell 7+ uses the
        # collection form (not the legacy Arguments string), which lets the
        # runtime handle argv quoting per-OS. Pre-joining or quoting the
        # caller-supplied values would re-introduce the very injection and
        # space-fragmentation bugs this helper exists to eliminate.
        foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            [System.Void] $process.Start()

            # READ BOTH STREAMS BEFORE WaitForExit() TO AVOID DEADLOCKING ON
            # COMMANDS THAT FILL EITHER PIPE'S OS BUFFER (typical limit ~4KB
            # on Windows). A WaitForExit() before draining the pipes would
            # hang any openssl invocation that emits more than that.
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError  = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            # ALWAYS BUILD THE RESULT OBJECT - EVEN ON FAILURE - SO THE
            # -IgnoreExitCode PATH HAS SOMETHING TO RETURN AND THE ERROR
            # MESSAGE BELOW CAN INCLUDE THE STDERR TEXT.
            $result = [PSCustomObject] @{
                ExitCode = $process.ExitCode
                StdOut   = $standardOutput
                StdErr   = $standardError
            }

            # DEFAULT BEHAVIOR: NON-ZERO EXIT IS TERMINATING. Including the
            # trimmed stderr in the message preserves diagnostics that were
            # previously lost by Start-Process -NoNewWindow (which silently
            # dropped the openssl error text).
            if ($process.ExitCode -ne 0 -and -not $IgnoreExitCode) {
                Write-Error -Message ("openssl exited with code {0}: {1}" -f $process.ExitCode, $standardError.Trim()) -Category InvalidResult -ErrorAction Stop
            }

            $result
        }
        finally {
            # ALWAYS DISPOSE - Process HOLDS UNMANAGED HANDLES (pipes, the
            # win32 process handle) THAT WILL LEAK UNTIL THE GC FINALIZER
            # RUNS IF NOT EXPLICITLY RELEASED.
            $process.Dispose()
        }
    }
}

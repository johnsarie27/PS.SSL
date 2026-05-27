function Test-OutputDirectoryPath {
    <#
    .SYNOPSIS
        Validate a candidate -OutputDirectory value.
    .DESCRIPTION
        Internal helper used by the `[ValidateScript({ ... })]` attribute on
        every public function's -OutputDirectory parameter. Centralizes the
        previously copy-pasted validation block so behavior and error wording
        stay identical across the module.

        Semantics:
          * The supplied path must not already exist as a file.
          * The parent directory must exist (so Initialize-OutputDirectory
            can safely materialize the leaf). A single-segment relative
            path (e.g. 'out') is treated as having parent '.' so it
            validates correctly when CWD is a real directory.

        On failure a terminating error is raised via
        `Write-Error -ErrorAction Stop`, which is what `ValidateScript`
        surfaces back to the parameter binder as a validation failure
        with a useful message. On success `$true` is returned so the
        attribute is happy.
    .PARAMETER Path
        Candidate output-directory path. May be absolute or relative,
        may or may not exist yet.
    .INPUTS
        None.
    .OUTPUTS
        System.Boolean. Always `$true` when the function returns
        normally; otherwise a terminating error is thrown.
    .EXAMPLE
        PS C:\> [ValidateScript({ Test-OutputDirectoryPath $_ })]
        PS C:\> [string] $OutputDirectory
    .NOTES
        Status: Stable
        - Paired with Private/Initialize-OutputDirectory.ps1, which
          handles the creation half once binding succeeds.
        - Uses `Write-Error -ErrorAction Stop` rather than `throw` to
          stay consistent with the module-wide error-emission convention.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [System.String] $Path
    )
    Process {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Error -Message 'OutputDirectory cannot be empty.' -ErrorAction Stop
        }

        if (Test-Path -Path $Path -PathType Leaf) {
            Write-Error -Message "OutputDirectory '$Path' exists but is a file, not a directory." -ErrorAction Stop
        }

        $parent = Split-Path -Path $Path -Parent
        if ([string]::IsNullOrEmpty($parent)) { $parent = '.' }

        if (-not (Test-Path -Path $parent -PathType Container)) {
            Write-Error -Message "Parent of OutputDirectory does not exist: $parent" -ErrorAction Stop
        }

        $true
    }
}

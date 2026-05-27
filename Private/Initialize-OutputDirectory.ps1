function Initialize-OutputDirectory {
    <#
    .SYNOPSIS
        Ensure an output directory exists, creating it if necessary.
    .DESCRIPTION
        Internal helper shared by every public function that writes
        artifacts to disk. Centralizes the previously copy-pasted
        "if (-not (Test-Path ...)) { New-Item ... }" snippet so the
        behavior (path testing, creation, verbose logging, error wording)
        is identical across the module.

        Designed to be paired with the matching `[ValidateScript()]`
        attribute on the public -OutputDirectory parameter: validation
        confirms the parent exists; this helper materializes the leaf.
    .PARAMETER Path
        Directory path to ensure exists. May be absolute or relative.
        If the path already exists and is a directory, the helper is a
        no-op. If it exists and is a file, a terminating error is raised.
        If it does not exist, the directory is created.
    .INPUTS
        None.
    .OUTPUTS
        None. Creates the directory as a side effect.
    .EXAMPLE
        PS C:\> Initialize-OutputDirectory -Path "$HOME\Desktop\out"
    .NOTES
        Status: Stable
        - Uses `Write-Error -ErrorAction Stop` rather than `throw` to
          stay consistent with the module-wide error-emission convention.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Path
    )
    Process {
        if (Test-Path -Path $Path -PathType Container) { return }

        if (Test-Path -Path $Path -PathType Leaf) {
            Write-Error -Message "Output directory path '$Path' exists but is a file, not a directory." -ErrorAction Stop
        }

        Write-Verbose -Message ('Creating output directory: {0}' -f $Path)
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

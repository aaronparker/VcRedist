Function Export-VcManifest {
    <#
        .SYNOPSIS
            Exports the Visual C++ Redistributables JSON to an external file.

        .DESCRIPTION
            Reads the Visual C++ Redistributables JSON manifests included in the VcRedist module and exports the JSON to an external file.
            This enables editing of the JSON manifest for custom scenarios.

        .OUTPUTS
            System.String
        
        .NOTES
            Name: Export-VcManifest
            Author: Aaron Parker
            Twitter: @stealthpuppy

        .LINK
            https://docs.stealthpuppy.com/vcredist/

        .PARAMETER Path
            Path to the JSON file the content will be exported to.

        .PARAMETER ExportAll
            Switch parameter that forces the export of Visual C++ Redistributables including unsupported Redistributables.

        .EXAMPLE
            Export-VcManifest -Path "C:\Temp\VisualCRedistributablesSupported.json"

            Description:
            Export the list of supported Visual C++ Redistributables to C:\Temp\VisualCRedistributablesSupported.json

        .EXAMPLE
            Export-VcManifest -Path "C:\Temp\VisualCRedistributables.json" -ExportAll

            Description:
            Export the full list Visual C++ Redistributables, including unsupported, to C:\Temp\VisualCRedistributables.json
    #>
    [Alias("Export-VcXml")]
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([String])]
    Param (
        [Parameter(Mandatory = $True, Position = 0, HelpMessage = "Path to the JSON file content will be exported to.")]
        [ValidateNotNull()]
        [ValidateScript({ If (Test-Path $(Split-Path -Path $_ -Parent) -PathType 'Container') { $True } Else { Throw "Cannot find path $(Split-Path -Path $_ -Parent)" } })]
        [string] $Path,

        [Parameter(Mandatory = $False)]
        [switch] $ExportAll = "Supported"
    )

    # Get the list of VcRedists from Get-VcList
    If ($ExportAll) {
        $vcList = Get-Vclist -ExportAll
    }
    Else {
        $vcList = Get-VcList
    }

    # Output the VcList object to a JSON file
    try {
        $vcList | ConvertTo-Json | Out-File -FilePath $Path -ErrorAction SilentlyContinue -ErrorVariable writeError
    }
    catch {
        Throw "Failed to write JSON to $Path with $writeError."
        Break
    }
    finally {
        Write-Output $Path
    }
}

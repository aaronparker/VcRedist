<#
    .SYNOPSIS
        Public Pester function tests.
#>
[OutputType()]
Param ()

#region Functions used in tests
Function Test-VcDownloads {
    <#
        .SYNOPSIS
            Tests downloads from Get-VcList are successful.
    #>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [PSCustomObject] $VcList,

        [Parameter()]
        [string] $Path
    )
    $Output = $False
    ForEach ($VcRedist in $VcList) {
        $folder = [System.IO.Path]::Combine((Resolve-Path -Path $Path), $VcRedist.Release, $VcRedist.Version, $VcRedist.Architecture)
        $Target = Join-Path $Folder $(Split-Path -Path $VcRedist.Download -Leaf)
        If (Test-Path -Path $Target -PathType Leaf) {
            Write-Verbose "$($Target) - exists."
            $Output = $True
        }
        Else {
            Write-Warning "$($Target) - not found."
            $Output = $False
        }
    }
    Write-Output $Output
}
#endregion

# Target download directory
If (Test-Path -Path env:Temp -ErrorAction "SilentlyContinue") {
    $downloadDir = $env:Temp
}
Else {
    $downloadDir = $env:TMPDIR
}
Write-Host -ForegroundColor Cyan "`tDownload dir: $downloadDir."

#region Function tests
Describe 'Get-VcList' -Tag "Get" {
    Context 'Return built-in manifest' {
        It 'Given no parameters, it returns supported Visual C++ Redistributables' {
            $VcList = Get-VcList
            $VcList | Should -HaveCount 8
        }
        It 'Given valid parameter -Export All, it returns all Visual C++ Redistributables' {
            $VcList = Get-VcList -Export All
            $VcList | Should -HaveCount 34
        }
        It 'Given valid parameter -Export Supported, it returns all Visual C++ Redistributables' {
            $VcList = Get-VcList -Export Supported
            $VcList | Should -HaveCount 12
        }
        It 'Given valid parameter -Export Unsupported, it returns unsupported Visual C++ Redistributables' {
            $VcList = Get-VcList -Export Unsupported
            $VcList | Should -HaveCount 22
        }
    }
    Context 'Validate Get-VcList array properties' {
        $VcList = Get-VcList
        ForEach ($VcRedist in $VcList) {
            It "VcRedist [$($VcRedist.Name), $($VcRedist.Architecture)] has expected properties" {
                $VcRedist.Name.Length | Should -BeGreaterThan 0
                $VcRedist.ProductCode.Length | Should -BeGreaterThan 0
                $VcRedist.Version.Length | Should -BeGreaterThan 0
                $VcRedist.URL.Length | Should -BeGreaterThan 0
                $VcRedist.Download.Length | Should -BeGreaterThan 0
                $VcRedist.Release.Length | Should -BeGreaterThan 0
                $VcRedist.Architecture.Length | Should -BeGreaterThan 0
                $VcRedist.Install.Length | Should -BeGreaterThan 0
                $VcRedist.SilentInstall.Length | Should -BeGreaterThan 0
                $VcRedist.SilentUninstall.Length | Should -BeGreaterThan 0
                $VcRedist.UninstallKey.Length | Should -BeGreaterThan 0
            }
        }
    }
    Context 'Return external manifest' {
        It 'Given valid parameter -Path, it returns Visual C++ Redistributables from an external manifest' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            $VcList = Get-VcList -Path $Json
            $VcList.Count | Should -BeGreaterOrEqual 8
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an JSON file that does not exist, it should throw an error' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "RedistsFail.json"
            { Get-VcList -Path $Json } | Should Throw
        }
        It 'Given an invalid JSON file, should throw an error on read' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "README.MD"
            { Get-VcList -Path $Json } | Should Throw
        }
    }
}

Describe 'Export-VcManifest' -Tag "Export" {
    Context 'Export manifest' {
        It 'Given valid parameter -Path, it exports an JSON file' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            Test-Path -Path $Json | Should -Be $True
        }
    }
    Context 'Export and read manifest' {
        It 'Given valid parameter -Path, it exports an JSON file' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            $VcList = Get-VcList -Path $Json
            $VcList.Count | Should -BeGreaterOrEqual 8
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an invalid path, it should throw an error' {
            { Export-VcManifest -Path (Join-Path -Path (Join-Path -Path $ProjectRoot -ChildPath "Temp") -ChildPath "Temp.json") } | Should Throw
        }
    }
}

Describe 'Save-VcRedist' -Tag "Save" {
    Context 'Download Redistributables' {
        It 'Downloads supported Visual C++ Redistributables' {
            If (Test-Path -Path $downloadDir -ErrorAction "SilentlyContinue") {
                $Path = Join-Path -Path $downloadDir -ChildPath "VcDownload"
                If (!(Test-Path $Path)) { New-Item $Path -ItemType Directory -Force > $Null }
                $VcList = Get-VcList
                Write-Host "`tDownloading VcRedists." -ForegroundColor Cyan
                Save-VcRedist -VcList $VcList -Path $Path
                Test-VcDownloads -VcList $VcList -Path $Path | Should -Be $True
            }
            Else {
                Write-Warning -Message "$downloadDir does not exist."
            }
        }
        It 'Returns an expected object type to the pipeline' {
            $Path = Join-Path -Path $downloadDir -ChildPath "VcDownload"
            If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Force }
            New-Item -Path $Path -ItemType Directory -Force > $Null
            
            Write-Host "`tDownloading VcRedists." -ForegroundColor Cyan
            $VcList = Get-VcList
            $DownloadedRedists = Save-VcRedist -VcList $VcList -Path $Path
            $DownloadedRedists | Should -BeOfType PSCustomObject
        }
    }
    Context "Test pipeline support" {
        It "Should not throw when passed via pipeline with no parameters" {
            If (Test-Path -Path $downloadDir -ErrorAction "SilentlyContinue") {
                New-Item -Path (Join-Path -Path $downloadDir -ChildPath "VcTest") -ItemType Directory -ErrorAction "SilentlyContinue" > $Null
                Push-Location -Path (Join-Path -Path $downloadDir -ChildPath "VcTest")
                Write-Host "`tDownloading VcRedists." -ForegroundColor Cyan
                { Get-VcList | Save-VcRedist } | Should -Not -Throw
                Pop-Location
            }
            Else {
                Write-Warning -Message "$downloadDir does not exist."
            }
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an invalid path, it should throw an error' {
            { Save-VcRedist -Path (Join-Path -Path $ProjectRoot -ChildPath "Temp") } | Should -Throw
        }
    }
}

Describe 'Install-VcRedist' -Tag "Install" {
    Context 'Install Redistributables' {
        If (Test-Path -Path $downloadDir -ErrorAction "SilentlyContinue") {
            $VcRedists = Get-VcList
            $Path = Join-Path -Path $downloadDir -ChildPath "VcDownload"
            Write-Host "`tInstalling VcRedists." -ForegroundColor Cyan
            $Installed = Install-VcRedist -VcList $VcRedists -Path $Path -Silent
            ForEach ($VcRedist in $VcRedists) {
                It "Installed the VcRedist: '$($VcRedist.Name)'" {
                    $VcRedist.ProductCode -match $Installed.ProductCode | Should -Not -BeNullOrEmpty
                }
            }
        }
        Else {
            Write-Warning -Message "$downloadDir does not exist."
        }
    }
}

If (($Null -eq $PSVersionTable.OS) -or ($PSVersionTable.OS -like "*Windows*")) {

    Describe 'Get-InstalledVcRedist' -Tag "Install" {
        Context 'Validate Get-InstalledVcRedist array properties' {
            $VcList = Get-InstalledVcRedist
            ForEach ($VcRedist in $VcList) {
                It "VcRedist '$($VcRedist.Name)' has expected properties" {
                    $VcRedist.Name.Length | Should -BeGreaterThan 0
                    $VcRedist.Version.Length | Should -BeGreaterThan 0
                    $VcRedist.ProductCode.Length | Should -BeGreaterThan 0
                    $VcRedist.UninstallString.Length | Should -BeGreaterThan 0
                }
            }
        }
    }

    Describe 'Uninstall-VcRedist' -Tag "Uninstall" {
        Context 'Uninstall VcRedists' {
            Write-Host "`tUninstalling VcRedists." -ForegroundColor Cyan
            { Uninstall-VcRedist -Release 2010, 2013 -Confirm:$False } | Should -Not -Throw
        }
    }
}
#endregion

#region Manifest test
# Get an array of VcRedists from the current manifest and the installed VcRedists
$Release = "2019"
Write-Host -ForegroundColor Cyan "`tGetting manifest from: $VcManifest."
$CurrentManifest = Get-Content -Path $VcManifest | ConvertFrom-Json
$InstalledVcRedists = Get-InstalledVcRedist
$UpdateManifest = $False

Describe 'VcRedist manifest tests' -Tag "Manifest" {
    Context 'Compare manifest version against installed version' {

        # Filter the VcRedists for the target version and compare against what has been installed
        ForEach ($ManifestVcRedist in ($CurrentManifest.Supported | Where-Object { $_.Release -eq $Release })) {
            $InstalledItem = $InstalledVcRedists | Where-Object { ($_.Release -eq $ManifestVcRedist.Release) -and ($_.Architecture -eq $ManifestVcRedist.Architecture) }
            If ($InstalledItem.Version -gt $ManifestVcRedist.Version) { $UpdateManifest = $True }

            # If the manifest version of the VcRedist is lower than the installed version, the manifest is out of date
            It "$($ManifestVcRedist.Release) $($ManifestVcRedist.Architecture) version should be current" {
                Write-Host -ForegroundColor Cyan "`tComparing installed: $($InstalledItem.Version). Against manifest: $($ManifestVcRedist.Version)."
                $InstalledItem.Version -gt $ManifestVcRedist.Version | Should -Be $False
            }
        }

        # Call update manifest script
        If ($UpdateManifest -eq $True) {
            . $ProjectRoot\ci\Update-Manifest.ps1
        }
    }
}
#endregion

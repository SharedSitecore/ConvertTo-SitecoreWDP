#Set-StrictMode -Version Latest
#####################################################
# ConvertTo-SitecoreWDP
#####################################################
<#PSScriptInfo

.VERSION 0.2

.GUID 4979bafc-b791-42b6-98c1-dd4c8eb586d0

.AUTHOR David Walker, Sitecore Dave, Radical Dave

.COMPANYNAME David Walker, Sitecore Dave, Radical Dave

.COPYRIGHT David Walker, Sitecore Dave, Radical Dave

.TAGS powershell sitecore package

.LICENSEURI https://github.com/SharedSitecore/ConvertTo-SitecoreWDP/blob/main/LICENSE

.PROJECTURI https://github.com/SharedSitecore/ConvertTo-SitecoreWDP

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

<# 

.DESCRIPTION 
 PowerShell Script to Create Sitecore WDP packages (helper/wrapper for Sitecore Azure Toolkit)

.PARAMETER name
Path of package

#> 
#####################################################
# ConvertTo-SitecoreWDP
#####################################################

[CmdletBinding(SupportsShouldProcess)]
Param(
	[Parameter(Mandatory=$true)]
	[string] $path,	
	[Parameter(Mandatory=$false)]
	[string] $destination = "",
	[Parameter(Mandatory=$false)]
	[string] $destinationPath = "",
	[Parameter(Mandatory=$false)]
	[string] $type = "module",
	[Parameter(Mandatory=$false)]
	[string] $satPath = "",	
	[Parameter(Mandatory=$false)]
	#[string] $satURL = "https://sitecoredev.azureedge.net/~/media/75A6FF723F0C48E991D7BB656DFA6FEF.ashx",
	[string] $satURL = "https://sitecoredev.azureedge.net/~/media/0041D6C02A8041E89C13B611B2432834.ashx",	
	[Parameter(Mandatory=$false)]
	#[string] $satPackageName = "Sitecore Azure Toolkit 2.6.1-r02533.1198.zip",
	[string] $satPackageName = "Sitecore Azure Toolkit 2.7.0-r02533.1285.zip",
	[Parameter(Mandatory=$false)]
	[switch] $removePostStep = $false,
	[Parameter(Mandatory=$false)]
	[switch] $skipCD = $false
)
begin {
	$ProgressPreference = "SilentlyContinue"		
	$ErrorActionPreference = 'Stop'
	$PSScriptName = ($MyInvocation.MyCommand.Name.Replace(".ps1",""))
	$PSCallingScript = if ($MyInvocation.PSCommandPath) { $MyInvocation.PSCommandPath | Split-Path -Parent } else { $null }
	Write-Verbose "$PSScriptRoot\$PSScriptName $path called by:$PSCallingScript"

	Install-Script -Name Install-Scripts -Confirm:$False -Force
	Install-Scripts @('Get-ArchiveEntries','Remove-ArchiveEntries','Set-ArchiveEntries','Import-SitecoreAzureToolkit')

	$paths = @()
	if((Test-Path $path) -and ($path.IndexOf("*") -eq -1 -and $path.IndexOf("/") -eq -1 -and $path.IndexOf("\") -eq -1)) {
		Write-Verbose "using path:$path"
		$paths = @($path)
	} else {
		if ($path.IndexOf('*') -ne -1 -or $path.IndexOf('/') -ne -1 -or $path.IndexOf('\') -ne -1) {
			if ($path.IndexOf(':') -eq -1) {
				$path = Join-Path (Get-Location) $path
			}
			Write-Verbose "path:$path"
			$paths = (Get-ChildItem -Path "$path").FullName			
		} else {
			Write-Verbose "path:$(Get-Location)\*-$path.zip"
			$paths = (Get-ChildItem -Path "$(Get-Location)\*-$path.zip").FullName	
		}
	}
	Write-Verbose "paths:$($paths.Length)"
}
process {
	try {
		Import-SitecoreAzureToolkit (Join-Path (Split-Path $PSScriptRoot -Parent) 'Convert-ToSitecoreWDP/SAT')			
		$paths.foreach({
			$path = $_
			Write-Verbose "path:$path"
			try {
				$file = (Split-Path $path -leaf).Replace('.zip', '')
				$tempFolder = "$ENV:Temp\ConvertTo-SitecoreWDP"
				if (Test-Path $tempFolder) { Remove-Item -Path $tempFolder -Recurse -Force}
				if (!(Test-Path $tempFolder)) { New-Item -Path $tempFolder -ItemType Directory}
				$source = "$ENV:Temp\ConvertTo-SitecoreWDP\$file.zip"
				Copy-Item $path $source -Force

				#if (!(Test-Path($path)) -and (-not(Split-Path $path -parent))) { $path = Join-Path (Get-Location) $path }
				Write-Verbose "source:$source"

				if (!$destinationPath) { $destinationPath = Join-Path (Split-Path $path -parent) 'scwdp' }
				$destination = Join-Path $destinationPath (Split-Path $path -leaf).Replace('.zip', '.scwdp.zip')

				#if (!$destination) { $destination = Join-Path $destinationPath (Split-Path $path -leaf).Replace('.zip', '.scwdp.zip')  }
				if (!(Test-Path($source))) {
					Write-Error "ERROR - Make sure the $path exists!"
				}
				else {
					if (!(Test-Path($destinationPath))) {
						New-Item -ItemType Directory -Force -Path $destinationPath
					}
					if (Test-Path($destination)) {
						Remove-Item -Path $destination -Force
					}
					if ($removePostStep -or $removePostStep -eq '$true') { 
						Set-ArchiveEntries $source @('metadata/sc_poststep.txt')
					}

					Write-Verbose "source:$source"
					Write-Verbose "destinationPath:$destinationPath"
					if ($type -eq 'module') {
						$results = ConvertTo-SCModuleWebDeployPackage -Path $source -Destination $destinationPath -Force
					} else {
						$results = ConvertTo-SCWebDeployPackage -Path $source -Destination $destinationPath -Force
					}
					Write-Host "SUCCESS. Generated: $results" -ForegroundColor Yellow
					
					if (!$skipCD) {
						$cmitems = Get-ArchiveEntries $path @('items/*','/properties/items/*')
						if ($cmitems.Count -gt 0) {
							$cdpath = $source.Replace('.zip','-CD.zip')
							Copy-Item $source $cdpath -Force
							Remove-ArchiveEntries $cdpath @('items/*','properties/items/*')
						}
					}
				}
			}
			catch {
				Write-Error "ERROR ConvertTo-SitecoreWDP $($path):$_" -InformationVariable results
			}
		})
		#if (Test-Path $tempFolder) { Remove-Item -Path $tempFolder -Recurse -Force}
	}
	catch {
		Write-Error "ERROR ConvertTo-SitecoreWDP $($path):$_" -InformationVariable results
	}
	
	Write-Verbose "$PSScriptName $path end"	
}
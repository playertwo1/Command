<#
.SYNOPSIS
    Script assistido de instalacao do Command Bridge (atalho raiz).
#>
[CmdletBinding()]
param(
    [string]$SourcePath = '',
    [string]$Version = '',
    [switch]$SkipHashCheck,
    [switch]$Silent,
    [switch]$NoRun
)

& (Join-Path $PSScriptRoot 'scripts\install.ps1') @PSBoundParameters

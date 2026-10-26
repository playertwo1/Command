<#
.SYNOPSIS
    Script assistido de desinstalacao do Command Bridge (atalho raiz).
#>
[CmdletBinding()]
param(
    [switch]$PurgeData,
    [switch]$RemoveFirewallRules,
    [switch]$Silent
)

& (Join-Path $PSScriptRoot 'scripts\uninstall.ps1') @PSBoundParameters

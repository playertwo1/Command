<#
.SYNOPSIS
    Script assistido de instalacao e verificacao de integridade do Command Bridge para Windows.

.DESCRIPTION
    Resolve o instalador 'Command-Setup.exe', valida o hash criptografico SHA-256 contra o
    manifesto ou arquivo .sha256 oficial antes da execucao, verifica o estado da assinatura
    Authenticode e executa a instalacao na sessao interativa do usuario sem privilegios de admin.
#>

[CmdletBinding()]
param(
    [string]$SourcePath = '',
    [string]$Version = '',
    [switch]$SkipHashCheck,
    [switch]$Silent,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Command Bridge - Instalador Assistido Windows (I0.3d)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Localiza o instalador
$setupExe = $null
$hashFile = $null
$manifestFile = $null

if ($SourcePath) {
    $resolvedSource = [System.IO.Path]::GetFullPath($SourcePath)
    if (Test-Path -LiteralPath $resolvedSource -PathType Leaf) {
        $setupExe = $resolvedSource
        $parentDir = Split-Path -Parent $setupExe
        $hashFile = Join-Path $parentDir "$([System.IO.Path]::GetFileName($setupExe)).sha256"
        $manifestFile = Join-Path $parentDir 'Command-Setup.manifest.json'
    }
    elseif (Test-Path -LiteralPath $resolvedSource -PathType Container) {
        $setupExe = Join-Path $resolvedSource 'Command-Setup.exe'
        $hashFile = Join-Path $resolvedSource 'Command-Setup.exe.sha256'
        $manifestFile = Join-Path $resolvedSource 'Command-Setup.manifest.json'
    }
}
elseif ($Version) {
    $versionDir = Join-Path $repoRoot "dist\command-installer\$Version"
    if (Test-Path -LiteralPath $versionDir) {
        $setupExe = Join-Path $versionDir 'Command-Setup.exe'
        $hashFile = Join-Path $versionDir 'Command-Setup.exe.sha256'
        $manifestFile = Join-Path $versionDir 'Command-Setup.manifest.json'
    }
    else {
        throw "Diretorio da versao '$Version' nao encontrado em '$versionDir'."
    }
}
else {
    # Busca versao mais recente na pasta de distribuicao local
    $distDir = Join-Path $repoRoot 'dist\command-installer'
    if (Test-Path -LiteralPath $distDir) {
        $candidates = @(Get-ChildItem -LiteralPath $distDir -Directory | Sort-Object LastWriteTime -Descending)
        foreach ($cand in $candidates) {
            $candExe = Join-Path $cand.FullName 'Command-Setup.exe'
            if (Test-Path -LiteralPath $candExe) {
                $setupExe = $candExe
                $hashFile = Join-Path $cand.FullName 'Command-Setup.exe.sha256'
                $manifestFile = Join-Path $cand.FullName 'Command-Setup.manifest.json'
                break
            }
        }
    }
}

if (-not $setupExe -or -not (Test-Path -LiteralPath $setupExe)) {
    throw "Instalador 'Command-Setup.exe' nao foi localizado. Execute 'scripts/build-command-installer.ps1' ou informe -SourcePath."
}

Write-Host "Instalador localizado: $setupExe" -ForegroundColor White
$fileInfo = Get-Item -LiteralPath $setupExe
$sizeMb = [Math]::Round($fileInfo.Length / 1MB, 2)
Write-Host "Tamanho: $sizeMb MB ($($fileInfo.Length) bytes)"

# 2. Resolucao do SHA-256 esperado
$expectedSha256 = $null

if (Test-Path -LiteralPath $hashFile) {
    $hashContent = (Get-Content -LiteralPath $hashFile -Raw).Trim()
    if ($hashContent -match '^([0-9a-fA-F]{64})') {
        $expectedSha256 = $matches[1].ToLowerInvariant()
        $leafName = Split-Path -Leaf $hashFile
        Write-Host "Hash esperado obtido de: $leafName" -ForegroundColor Gray
    }
}

if (-not $expectedSha256 -and (Test-Path -LiteralPath $manifestFile)) {
    try {
        $manifestJson = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
        if ($manifestJson.installerSha256) {
            $expectedSha256 = $manifestJson.installerSha256.ToLowerInvariant()
            $manifestLeaf = Split-Path -Leaf $manifestFile
            Write-Host "Hash esperado obtido de: $manifestLeaf" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Falha ao ler o manifesto: $($_.Exception.Message)"
    }
}

# 3. Validacao de integridade criptografica
if ($expectedSha256) {
    Write-Host "Calculando hash SHA-256 do arquivo..." -ForegroundColor Yellow
    $actualHash = (Get-FileHash -LiteralPath $setupExe -Algorithm SHA256).Hash.ToLowerInvariant()

    Write-Host "SHA-256 Esperado: $expectedSha256"
    Write-Host "SHA-256 Obtido:   $actualHash"

    if ($actualHash -eq $expectedSha256) {
        Write-Host "[OK] Integridade criptografica SHA-256 CONFIRMADA!" -ForegroundColor Green
    }
    else {
        Write-Host "[ERRO CRITICO] DIVERGENCIA NO HASH CRIPTOGRAFICO!" -ForegroundColor Red
        throw "CHECKSUM_MISMATCH: O hash do arquivo '$setupExe' diverge do valor oficial. A instalacao foi abortada por seguranca contra adulteracao."
    }
}
elseif ($SkipHashCheck) {
    Write-Warning "Aviso: Nenhum arquivo de hash (.sha256 ou manifesto) foi encontrado. A checagem foi pulada (-SkipHashCheck)."
}
else {
    throw "Arquivo de hash de integridade (.sha256 ou manifesto) nao encontrado para '$setupExe'. Forneca o arquivo correspondente ou use -SkipHashCheck conscientemente."
}

# 4. Verificacao de assinatura Authenticode
$signature = Get-AuthenticodeSignature -LiteralPath $setupExe
$sigStatus = $signature.Status.ToString()
Write-Host "Assinatura Authenticode: $sigStatus" -ForegroundColor $(if ($sigStatus -eq 'Valid') { 'Green' } else { 'Yellow' })
if ($sigStatus -ne 'Valid') {
    Write-Host "  Nota: Piloto local ou binario sem certificado EV comercial (esperado em ambiente de desenvolvimento)." -ForegroundColor Gray
}

# 5. Execucao do instalador
if ($NoRun) {
    Write-Host ""
    Write-Host "Modo -NoRun ativo: Verificacao de integridade concluida com sucesso. Nenhuma instalacao disparada." -ForegroundColor Green
    return
}

if (-not $Silent) {
    Write-Host ""
    $confirm = Read-Host "Deseja executar o instalador 'Command-Setup.exe' agora? (S/N)"
    if ($confirm -notmatch '^[sSyY]') {
        Write-Host "Instalacao cancelada pelo usuario." -ForegroundColor Yellow
        return
    }
}

Write-Host "Iniciando instalador na sessao do usuario..." -ForegroundColor Cyan
Start-Process -FilePath $setupExe
Write-Host "Instalador iniciado com sucesso." -ForegroundColor Green

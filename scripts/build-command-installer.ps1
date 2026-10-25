[CmdletBinding()]
param(
    [string]$Version = '1.1.0-local.20261024.x64',
    [string]$DotnetPath = '',
    [string]$FlutterPath = '',
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$assemblyVersion = $Version.Split('-')[0]
$vpkVersion = '1.2.161'
$packageId = 'CommandPC'

if ($Version -notmatch '^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$') {
    throw "Versao Velopack invalida: '$Version'. Use SemVer, por exemplo 1.1.0-local.20261024."
}

function Resolve-Tool([string]$RequestedPath, [string]$FallbackPath, [string]$CommandName) {
    if ($RequestedPath) {
        if (Test-Path -LiteralPath $RequestedPath) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        $requestedCommand = Get-Command $RequestedPath -ErrorAction SilentlyContinue
        if ($requestedCommand) { return $requestedCommand.Source }
        throw "Ferramenta nao encontrada: $RequestedPath"
    }
    if ($FallbackPath -and (Test-Path -LiteralPath $FallbackPath)) {
        return (Resolve-Path -LiteralPath $FallbackPath).Path
    }
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Ferramenta '$CommandName' nao encontrada. Informe o caminho em -$($CommandName.Substring(0,1).ToUpperInvariant() + $CommandName.Substring(1))Path."
}

function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Comando falhou (exit $LASTEXITCODE): $Executable $($Arguments -join ' ')"
    }
}

$localDotnet = Join-Path $repoRoot 'research\upstream\.tools\dotnet-8.0.426\dotnet.exe'
$localFlutter = Join-Path $repoRoot 'research\upstream\.tools\flutter\bin\flutter.bat'
$dotnet = Resolve-Tool $DotnetPath $localDotnet 'dotnet'
$flutter = Resolve-Tool $FlutterPath $localFlutter 'flutter'

$outputBase = if ($OutputRoot) { [System.IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $repoRoot 'dist\command-installer' }
$outputDir = Join-Path $outputBase $Version
if (Test-Path -LiteralPath $outputDir) {
    throw "Saida ja existe; nada foi sobrescrito: $outputDir"
}

$scratchBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$buildRoot = Join-Path $scratchBase ('command-installer-build-' + [Guid]::NewGuid().ToString('N'))
$publishDir = Join-Path $buildRoot 'publish'
$packageDir = Join-Path $buildRoot 'velopack'
$vpkToolDir = Join-Path $buildRoot 'tools'
$appDir = Join-Path $repoRoot 'app'
$appBuildRoot = Join-Path $appDir 'build'
$createdAppBuildRoot = -not (Test-Path -LiteralPath $appBuildRoot)
$previousPubCache = $env:PUB_CACHE
$previousNugetPackages = $env:NUGET_PACKAGES
$previousDotnetHome = $env:DOTNET_CLI_HOME
$previousDotnetNoLogo = $env:DOTNET_NOLOGO
$previousFlutterAnalytics = $env:FLUTTER_SUPPRESS_ANALYTICS
$previousDartAnalytics = $env:DART_SUPPRESS_ANALYTICS
$env:PUB_CACHE = Join-Path $buildRoot 'pub-cache'
$env:NUGET_PACKAGES = Join-Path $buildRoot 'nuget-packages'
$env:DOTNET_CLI_HOME = Join-Path $buildRoot 'dotnet-home'
$env:DOTNET_NOLOGO = '1'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'

try {
    New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

    Write-Host "Restaurando dependencias Flutter para Command..."
    Push-Location $appDir
    try {
        Invoke-Checked $flutter @('pub', 'get', '--enforce-lockfile')
        Invoke-Checked $flutter @('build', 'web', '--release', '--no-pub')
    }
    finally { Pop-Location }

    $webDir = Join-Path $appBuildRoot 'web'
    if (-not (Test-Path -LiteralPath (Join-Path $webDir 'index.html'))) {
        throw "Build Flutter web nao gerou index.html: $webDir"
    }

    Write-Host "Publicando Bridge autocontida para win-x64..."
    Invoke-Checked $dotnet @(
        'publish', (Join-Path $repoRoot 'DroidDeck\DroidDeck.csproj'),
        '-c', 'Release', '-r', 'win-x64', '--self-contained', 'true',
        '-p:PublishSingleFile=false', "-p:Version=$assemblyVersion", '-o', $publishDir
    )
    Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $publishDir 'LICENSE')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'app\LICENSE') -Destination (Join-Path $publishDir 'LICENSE-APP-GPL-3.0')

    $publishedWebDir = Join-Path $publishDir 'wwwroot'
    $publishRootFull = [System.IO.Path]::GetFullPath($publishDir).TrimEnd('\') + '\'
    $publishedWebFull = [System.IO.Path]::GetFullPath($publishedWebDir)
    if (-not $publishedWebFull.StartsWith($publishRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Destino wwwroot fora da pasta temporaria de publish: $publishedWebFull"
    }
    if (Test-Path -LiteralPath $publishedWebDir) {
        Remove-Item -LiteralPath $publishedWebDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $publishedWebDir -Force | Out-Null
    Copy-Item -Path (Join-Path $webDir '*') -Destination $publishedWebDir -Recurse -Force

    Write-Host "Instalando Velopack CLI $vpkVersion no scratch local..."
    Invoke-Checked $dotnet @('tool', 'install', 'vpk', '--tool-path', $vpkToolDir, '--version', $vpkVersion)
    $vpk = Join-Path $vpkToolDir 'vpk.exe'
    if (-not (Test-Path -LiteralPath $vpk)) { throw "vpk.exe nao encontrado em $vpkToolDir" }

    Invoke-Checked $vpk @(
        'pack', '--runtime', 'win-x64', '--packId', $packageId, '--packVersion', $Version,
        '--packDir', $publishDir, '--mainExe', 'DroidDeck.exe',
        '--packTitle', 'Command', '--packAuthors', 'Command',
        '--icon', (Join-Path $repoRoot 'DroidDeck\volume-_2_.ico'),
        '--outputDir', $packageDir
    )

    $setupSource = Join-Path $packageDir "$packageId-win-Setup.exe"
    if (-not (Test-Path -LiteralPath $setupSource)) {
        $setups = @(Get-ChildItem -LiteralPath $packageDir -Filter '*-win-Setup.exe' -File)
        if ($setups.Count -ne 1) { throw "Esperava um Setup Velopack, encontrados: $($setups.Count)" }
        $setupSource = $setups[0].FullName
    }

    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $setupPath = Join-Path $outputDir 'Command-Setup.exe'
    Copy-Item -LiteralPath $setupSource -Destination $setupPath
    $sha256 = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$setupPath.sha256" -Value "$sha256  Command-Setup.exe" -Encoding Ascii

    $commit = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel identificar o commit de origem.' }
    $dirtyEntries = @(& git -C $repoRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel verificar se a arvore de origem esta limpa.' }
    $signatureStatus = (Get-AuthenticodeSignature -LiteralPath $setupPath).Status.ToString()
    $manifest = [ordered]@{
        product = 'Command'
        packageId = $packageId
        version = $Version
        architecture = 'win-x64'
        sourceCommit = $commit
        sourceWorkingTreeDirty = ($dirtyEntries.Count -gt 0)
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        dataRoots = @('%LocalAppData%\Command', '%AppData%\Command')
        updateFeed = 'disabled for local pilot; no upstream fallback'
        authenticodeStatus = $signatureStatus
        installerSha256 = $sha256
    }
    $manifestJson = $manifest | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText(
        (Join-Path $outputDir 'Command-Setup.manifest.json'),
        $manifestJson,
        ([System.Text.UTF8Encoding]::new($false))
    )

    Write-Host "Instalador gerado: $setupPath"
    Write-Host "SHA-256: $sha256"
    Write-Host "Assinatura Authenticode: $signatureStatus"
}
finally {
    $env:PUB_CACHE = $previousPubCache
    $env:NUGET_PACKAGES = $previousNugetPackages
    $env:DOTNET_CLI_HOME = $previousDotnetHome
    $env:DOTNET_NOLOGO = $previousDotnetNoLogo
    $env:FLUTTER_SUPPRESS_ANALYTICS = $previousFlutterAnalytics
    $env:DART_SUPPRESS_ANALYTICS = $previousDartAnalytics

    if ($createdAppBuildRoot -and (Test-Path -LiteralPath $appBuildRoot)) {
        $appRootFull = [System.IO.Path]::GetFullPath($appDir).TrimEnd('\') + '\'
        $appBuildFull = [System.IO.Path]::GetFullPath($appBuildRoot)
        if ($appBuildFull.StartsWith($appRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $appBuildFull -Recurse -Force
        }
    }

    $buildRootFull = [System.IO.Path]::GetFullPath($buildRoot)
    if ($buildRootFull.StartsWith($scratchBase.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $buildRootFull).StartsWith('command-installer-build-', [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $buildRootFull)) {
        Remove-Item -LiteralPath $buildRootFull -Recurse -Force
    }
}

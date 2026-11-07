<#
.SYNOPSIS
    Script assistido de desinstalacao e limpeza do Command Bridge para Windows (I0.5).

.DESCRIPTION
    Encerra processos em execucao, remove atalhos de inicializacao com o Windows (autostart),
    oferece remocao de regras de firewall do Command e dispara a desinstalacao nativa.
    Preserva as pastas de perfis e dados por padrao (%AppData%\Command e %LocalAppData%\Command),
    a menos que a flag -PurgeData seja explicitamente informada com confirmacao.
#>

[CmdletBinding()]
param(
    [switch]$PurgeData,
    [switch]$RemoveFirewallRules,
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Command Bridge - Desinstalador Assistido Windows (I0.5)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Encerra processos ativos do Command
Write-Host "Verificando processos ativos do Command..." -ForegroundColor Yellow
$procs = @(Get-Process -Name "Command", "DroidDeck" -ErrorAction SilentlyContinue)
if ($procs.Count -gt 0) {
    Write-Host "Encerrando $($procs.Count) processo(s) do Command em execucao..." -ForegroundColor Gray
    foreach ($p in $procs) {
        try {
            $p.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 500
            if (-not $p.HasExited) { $p.Kill() }
        }
        catch { }
    }
    Write-Host "[OK] Processos encerrados." -ForegroundColor Green
}
else {
    Write-Host "[OK] Nenhum processo ativo encontrado." -ForegroundColor Gray
}

# 2. Remove entrada de autostart (RunKey)
Write-Host "Removendo entrada de inicializacao automatica com o Windows..." -ForegroundColor Yellow
$runKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$entry = Get-ItemProperty -Path $runKeyPath -Name "Command" -ErrorAction SilentlyContinue
if ($entry) {
    Remove-ItemProperty -Path $runKeyPath -Name "Command" -ErrorAction SilentlyContinue
    Write-Host "[OK] Autostart removido do registro do usuario." -ForegroundColor Green
}
else {
    Write-Host "[OK] Nenhuma entrada de autostart encontrada." -ForegroundColor Gray
}

# 3. Regras de firewall
if ($RemoveFirewallRules) {
    Write-Host "Removendo regras de firewall do Command (pode exigir elevacao UAC)..." -ForegroundColor Yellow
    $rules = @("Command (TCP 4787)", "Command control (TCP 4788)", "Command discovery (UDP 7573)")
    foreach ($r in $rules) {
        try {
            Start-Process -FilePath "netsh" -ArgumentList "advfirewall firewall delete rule name=`"$r`"" -WindowStyle Hidden -Wait
        }
        catch { }
    }
    Write-Host "[OK] Regras de firewall limpas." -ForegroundColor Green
}

# 4. Desinstalacao nativa do Velopack se instalada
$localAppData = $env:LOCALAPPDATA
$velopackUpdater = Join-Path $localAppData "CommandPC\Update.exe"

if (Test-Path -LiteralPath $velopackUpdater) {
    Write-Host "Disparando desinstalador nativo do Velopack ($velopackUpdater)..." -ForegroundColor Yellow
    try {
        $uninstallArgs = @("--uninstall")
        if ($Silent) { $uninstallArgs += "--silent" }
        $p = Start-Process -FilePath $velopackUpdater -ArgumentList $uninstallArgs -Wait -PassThru
        Write-Host "[OK] Desinstalador Velopack finalizado com codigo $($p.ExitCode)." -ForegroundColor Green
    }
    catch {
        Write-Warning "Falha ao executar o desinstalador nativo: $($_.Exception.Message)"
    }
}
else {
    Write-Host "[INFO] Velopack Update.exe nao encontrado em $velopackUpdater (copia portatil ou zip)." -ForegroundColor Gray
}

# 5. Tratamento dos dados do usuario (preservacao por padrao)
$roamingDir = Join-Path $env:APPDATA "Command"
$localDir = Join-Path $localAppData "Command"

if ($PurgeData) {
    $confirmPurge = $Silent
    if (-not $confirmPurge) {
        Write-Host ""
        Write-Host "AVISO DE EXCLUSAO DE DADOS:" -ForegroundColor Red
        Write-Host "As pastas de configuracao, perfis e credenciais serao permanentemente apagadas:" -ForegroundColor Yellow
        Write-Host "  - $roamingDir"
        Write-Host "  - $localDir"
        $answer = Read-Host "Tem certeza absoluta que deseja apagar todos os dados do Command? (Digite 'APAGAR' para confirmar)"
        $confirmPurge = ($answer -ceq "APAGAR")
    }

    if ($confirmPurge) {
        Write-Host "Removendo pastas de dados..." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $roamingDir) { Remove-Item -LiteralPath $roamingDir -Recurse -Force }
        if (Test-Path -LiteralPath $localDir) { Remove-Item -LiteralPath $localDir -Recurse -Force }
        Write-Host "[OK] Pastas de dados excluidas." -ForegroundColor Green
    }
    else {
        Write-Host "Exclusao de dados cancelada. Os dados foram preservados." -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[PRESERVACAO DE DADOS]" -ForegroundColor Cyan
    Write-Host "Suas configuracoes e perfis foram mantidos intactos em:" -ForegroundColor Gray
    Write-Host "  - $roamingDir" -ForegroundColor Gray
    Write-Host "  - $localDir" -ForegroundColor Gray
    Write-Host "Para remove-los no futuro, use -PurgeData." -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Desinstalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

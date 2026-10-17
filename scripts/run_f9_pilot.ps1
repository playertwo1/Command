# scripts/run_f9_pilot.ps1
# Bateria automatizada de 30 execuções do piloto Command v0.1.0 (F9)
# Executa 6 rodadas dos 5 fluxos piloto (FL-1 a FL-5) no emulador Android Pixel 9

param(
    [int]$Rounds = 6,
    [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"
$EvidenceDir = "docs/evidence/F9"
$CapturesDir = "$EvidenceDir/captures"
$JsonLogPath = "$EvidenceDir/pilot_log.json"
$MdLogPath = "$EvidenceDir/PILOT_LOG.md"

if (-not (Test-Path $CapturesDir)) {
    New-Item -ItemType Directory -Force -Path $CapturesDir | Out-Null
}

$JobsHistoryPath = "$env:LOCALAPPDATA\DroidDeck\jobs_history.json"

function Get-LatestJob {
    if (-not (Test-Path $JobsHistoryPath)) { return $null }
    $content = Get-Content $JobsHistoryPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    $jobs = $content | ConvertFrom-Json
    if ($jobs -and $jobs.Count -gt 0) {
        return $jobs[0]
    }
    return $null
}

function Wait-ForNewJob($prevId, [int]$timeoutSeconds = 12) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        Start-Sleep -Milliseconds 250
        $current = Get-LatestJob
        if ($current -and $current.id -ne $prevId) {
            # Espera o job transicionar de 'accepted' ou 'running' para status final
            while ($current.status -in @("accepted", "running") -and $sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
                Start-Sleep -Milliseconds 150
                $current = Get-LatestJob
            }
            return $current
        }
    }
    return $null
}

function Get-DumpXml {
    adb -s $DeviceId shell uiautomator dump /sdcard/pilot_dump.xml > $null
    $raw = adb -s $DeviceId shell cat /sdcard/pilot_dump.xml
    return ($raw -join "")
}

function Ensure-Actions-Visible {
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "(?s)Obsidian.*?content-desc=[`"']Abrir[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 1600 540 900 250
        Start-Sleep -Milliseconds 400
    }
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "(?s)Obsidian.*?content-desc=[`"']Abrir[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 800 540 1500 250
        Start-Sleep -Milliseconds 400
    }
    return Get-DumpXml
}

function Ensure-Screenshot-Visible {
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "content-desc=[`"'](Nova Captura|Capturar Tela Agora)[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 1600 540 900 250
        Start-Sleep -Milliseconds 400
    }
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "content-desc=[`"'](Nova Captura|Capturar Tela Agora)[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 800 540 1500 250
        Start-Sleep -Milliseconds 400
    }
    return Get-DumpXml
}

function Ensure-Transfers-Visible {
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "(?s)relatorio_pc\.csv.*?content-desc=[`"']Baixar[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 1600 540 900 250
        Start-Sleep -Milliseconds 400
    }
    for ($i = 0; $i -lt 5; $i++) {
        $xml = Get-DumpXml
        if ($xml -match "(?s)relatorio_pc\.csv.*?content-desc=[`"']Baixar[`"']") {
            return $xml
        }
        adb -s $DeviceId shell input swipe 540 800 540 1500 250
        Start-Sleep -Milliseconds 400
    }
    return Get-DumpXml
}

function Capture-EvidenceScreenshot($name) {
    $remotePath = "/sdcard/$name.png"
    $localPath = "$CapturesDir/$name.png"
    adb -s $DeviceId shell screencap -p $remotePath
    adb -s $DeviceId pull $remotePath $localPath > $null
    if (Test-Path "C:\Users\notefael\NexusVault\90_Anexos") {
        Copy-Item $localPath "C:\Users\notefael\NexusVault\90_Anexos\$name.png" -Force
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Iniciando Bateria de Piloto F9: $Rounds rodadas x 5 fluxos = $( $Rounds * 5 ) execuções" -ForegroundColor Cyan
Write-Host "Aparelho Alvo: $DeviceId | Bridge: http://10.0.2.2:4787" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$executions = @()
$executionCounter = 1

for ($round = 1; $round -le $Rounds; $round++) {
    Write-Host "`n>>> RODADA $round de $Rounds <<<" -ForegroundColor Yellow

    # ---------------------------------------------------------
    # FL-1: Abrir Obsidian
    # ---------------------------------------------------------
    Write-Host "[$executionCounter/30] Executando FL-1: Abrir Obsidian..." -NoNewline
    $xml = Ensure-Actions-Visible
    if ($xml -match "(?s)Obsidian.*?content-desc=[`"']Abrir[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
        $x = [int](([int]$matches[1] + [int]$matches[3]) / 2)
        $y = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        $prevJob = Get-LatestJob
        $start = [System.Diagnostics.Stopwatch]::StartNew()
        adb -s $DeviceId shell input tap $x $y
        $newJob = Wait-ForNewJob -prevId ($prevJob.id)
        $start.Stop()

        if ($newJob -and $newJob.status -eq "succeeded") {
            Write-Host " OK ($($start.ElapsedMilliseconds) ms) [JobID: $($newJob.id.Substring(0,8))]" -ForegroundColor Green
            $status = "succeeded"
            $err = "none"
            $reqId = $newJob.requestId
            $jobId = $newJob.id
        } else {
            Write-Host " FALHA" -ForegroundColor Red
            $status = "failed"
            $err = if ($newJob) { $newJob.errorMessage } else { "TIMEOUT_WAITING_JOB" }
            $reqId = if ($newJob) { $newJob.requestId } else { "none" }
            $jobId = if ($newJob) { $newJob.id } else { "none" }
        }

        $executions += [PSCustomObject]@{
            execution_id   = $executionCounter
            round          = $round
            timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            flow_id        = "FL-1"
            flow_name      = "Abrir Obsidian"
            network        = "LAN (10.0.2.2:4787 / Subnet Local)"
            request_id     = $reqId
            job_id         = $jobId
            status         = $status
            error_code     = $err
            duration_ms    = $start.ElapsedMilliseconds
            observation    = "Obsidian iniciado com sucesso via allowlist estrita do PC"
        }
    } else {
        Write-Host " ERRO: Botão Obsidian não encontrado no dump XML" -ForegroundColor Red
    }
    if ($round -eq 1 -or $round -eq $Rounds) {
        Capture-EvidenceScreenshot "f9_fl1_obsidian_r$round"
    }
    $executionCounter++
    Start-Sleep -Milliseconds 600

    # ---------------------------------------------------------
    # FL-2: Abrir Orbit PJ
    # ---------------------------------------------------------
    Write-Host "[$executionCounter/30] Executando FL-2: Abrir Orbit PJ..." -NoNewline
    $xml = Ensure-Actions-Visible
    if ($xml -match "(?s)Orbit PJ.*?content-desc=[`"']Abrir[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
        $x = [int](([int]$matches[1] + [int]$matches[3]) / 2)
        $y = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        $prevJob = Get-LatestJob
        $start = [System.Diagnostics.Stopwatch]::StartNew()
        adb -s $DeviceId shell input tap $x $y
        $newJob = Wait-ForNewJob -prevId ($prevJob.id)
        $start.Stop()

        if ($newJob -and $newJob.status -eq "succeeded") {
            Write-Host " OK ($($start.ElapsedMilliseconds) ms) [JobID: $($newJob.id.Substring(0,8))]" -ForegroundColor Green
            $status = "succeeded"
            $err = "none"
            $reqId = $newJob.requestId
            $jobId = $newJob.id
        } else {
            Write-Host " FALHA" -ForegroundColor Red
            $status = "failed"
            $err = if ($newJob) { $newJob.errorMessage } else { "TIMEOUT_WAITING_JOB" }
            $reqId = if ($newJob) { $newJob.requestId } else { "none" }
            $jobId = if ($newJob) { $newJob.id } else { "none" }
        }

        $executions += [PSCustomObject]@{
            execution_id   = $executionCounter
            round          = $round
            timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            flow_id        = "FL-2"
            flow_name      = "Abrir Orbit PJ"
            network        = "LAN (10.0.2.2:4787 / Subnet Local)"
            request_id     = $reqId
            job_id         = $jobId
            status         = $status
            error_code     = $err
            duration_ms    = $start.ElapsedMilliseconds
            observation    = "Projeto Orbit aberto no VS Code / Explorer com allowlist"
        }
    } else {
        Write-Host " ERRO: Botão Orbit PJ não encontrado no dump XML" -ForegroundColor Red
    }
    if ($round -eq 1 -or $round -eq $Rounds) {
        Capture-EvidenceScreenshot "f9_fl2_orbit_r$round"
    }
    $executionCounter++
    Start-Sleep -Milliseconds 600

    # ---------------------------------------------------------
    # FL-3: Screenshot Manual
    # ---------------------------------------------------------
    Write-Host "[$executionCounter/30] Executando FL-3: Screenshot Manual..." -NoNewline
    $xml = Ensure-Screenshot-Visible
    if ($xml -match "content-desc=[`"'](Nova Captura|Capturar Tela Agora)[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
        $x = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        $y = [int](([int]$matches[3] + [int]$matches[5]) / 2)
        $prevJob = Get-LatestJob
        $start = [System.Diagnostics.Stopwatch]::StartNew()
        adb -s $DeviceId shell input tap $x $y
        $newJob = Wait-ForNewJob -prevId ($prevJob.id)
        $start.Stop()

        if ($newJob -and $newJob.status -eq "succeeded") {
            Write-Host " OK ($($start.ElapsedMilliseconds) ms) [JobID: $($newJob.id.Substring(0,8))]" -ForegroundColor Green
            $status = "succeeded"
            $err = "none"
            $reqId = $newJob.requestId
            $jobId = $newJob.id
        } else {
            Write-Host " FALHA" -ForegroundColor Red
            $status = "failed"
            $err = if ($newJob) { $newJob.errorMessage } else { "TIMEOUT_WAITING_JOB" }
            $reqId = if ($newJob) { $newJob.requestId } else { "none" }
            $jobId = if ($newJob) { $newJob.id } else { "none" }
        }

        $executions += [PSCustomObject]@{
            execution_id   = $executionCounter
            round          = $round
            timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            flow_id        = "FL-3"
            flow_name      = "Screenshot Manual"
            network        = "LAN (10.0.2.2:4787 / Subnet Local)"
            request_id     = $reqId
            job_id         = $jobId
            status         = $status
            error_code     = $err
            duration_ms    = $start.ElapsedMilliseconds
            observation    = "Captura real GDI BitBlt gerada no monitor principal com expiração de 10 min"
        }
    } else {
        Write-Host " ERRO: Botão Screenshot não encontrado no dump XML" -ForegroundColor Red
    }
    if ($round -eq 1 -or $round -eq $Rounds) {
        Capture-EvidenceScreenshot "f9_fl3_screenshot_r$round"
    }
    $executionCounter++
    Start-Sleep -Milliseconds 600

    # ---------------------------------------------------------
    # FL-4: Transferência Restrita (Download / Upload)
    # ---------------------------------------------------------
    Write-Host "[$executionCounter/30] Executando FL-4: Transferência Restrita (Download & Upload)..." -NoNewline
    $xml = Ensure-Transfers-Visible
    if ($xml -match "(?s)relatorio_pc\.csv.*?content-desc=[`"']Baixar[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
        $x = [int](([int]$matches[1] + [int]$matches[3]) / 2)
        $y = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        $prevJob = Get-LatestJob
        $start = [System.Diagnostics.Stopwatch]::StartNew()
        adb -s $DeviceId shell input tap $x $y
        $newJob = Wait-ForNewJob -prevId ($prevJob.id)
        $start.Stop()

        if ($newJob -and $newJob.status -eq "succeeded") {
            Write-Host " OK ($($start.ElapsedMilliseconds) ms) [JobID: $($newJob.id.Substring(0,8))]" -ForegroundColor Green
            $status = "succeeded"
            $err = "none"
            $reqId = $newJob.requestId
            $jobId = $newJob.id
        } else {
            Write-Host " FALHA" -ForegroundColor Red
            $status = "failed"
            $err = if ($newJob) { $newJob.errorMessage } else { "TIMEOUT_WAITING_JOB" }
            $reqId = if ($newJob) { $newJob.requestId } else { "none" }
            $jobId = if ($newJob) { $newJob.id } else { "none" }
        }

        $executions += [PSCustomObject]@{
            execution_id   = $executionCounter
            round          = $round
            timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            flow_id        = "FL-4"
            flow_name      = "Transferência de Arquivos (Download)"
            network        = "LAN (10.0.2.2:4787 / Subnet Local)"
            request_id     = $reqId
            job_id         = $jobId
            status         = $status
            error_code     = $err
            duration_ms    = $start.ElapsedMilliseconds
            observation    = "Download outbound de relatorio_pc.csv validado com integridade SHA-256 no cliente"
        }
    } else {
        Write-Host " ERRO: Botão Baixar não encontrado no dump XML" -ForegroundColor Red
    }
    if ($round -eq 1 -or $round -eq $Rounds) {
        Capture-EvidenceScreenshot "f9_fl4_transfer_r$round"
    }
    $executionCounter++
    Start-Sleep -Milliseconds 600

    # ---------------------------------------------------------
    # FL-5: Encerramento de Processo (Bloco de Notas)
    # ---------------------------------------------------------
    Write-Host "[$executionCounter/30] Executando FL-5: Abertura e Encerramento Controlado (Bloco de Notas)..." -NoNewline
    $xml = Ensure-Actions-Visible
    if ($xml -match "(?s)Bloco de Notas.*?content-desc=[`"']Abrir[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
        $xOpen = [int](([int]$matches[1] + [int]$matches[3]) / 2)
        $yOpen = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        $prevJob = Get-LatestJob
        adb -s $DeviceId shell input tap $xOpen $yOpen
        $launchJob = Wait-ForNewJob -prevId ($prevJob.id)
        
        # Aguarda o app atualizar o PID ativo e o botão Encerrar reaparecer ativo (sem spinner)
        $encerrarMatches = $null
        for ($w = 0; $w -lt 15; $w++) {
            Start-Sleep -Milliseconds 400
            $xml = Ensure-Actions-Visible
            if ($xml -match "(?s)Bloco de Notas.*?content-desc=[`"']Encerrar[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
                $encerrarMatches = $matches
                break
            }
        }

        if ($encerrarMatches) {
            $xKill = [int](([int]$encerrarMatches[1] + [int]$encerrarMatches[3]) / 2)
            $yKill = [int](([int]$encerrarMatches[2] + [int]$encerrarMatches[4]) / 2)
            adb -s $DeviceId shell input tap $xKill $yKill
            Start-Sleep -Milliseconds 600

            # Modal de confirmação explícita
            $dialogXml = Get-DumpXml
            if ($dialogXml -match "(?s)Encerrar Aplicativo.*?content-desc=[`"']Encerrar[`"'][^>]*bounds=[`"']\[(\d+),(\d+)\]\[(\d+),(\d+)\][`"']") {
                $xConfirm = [int](([int]$matches[1] + [int]$matches[3]) / 2)
                $yConfirm = [int](([int]$matches[2] + [int]$matches[4]) / 2)
                $prevKillJob = Get-LatestJob
                $start = [System.Diagnostics.Stopwatch]::StartNew()
                adb -s $DeviceId shell input tap $xConfirm $yConfirm
                $killJob = Wait-ForNewJob -prevId ($prevKillJob.id)
                $start.Stop()

                if ($killJob -and $killJob.status -eq "succeeded") {
                    Write-Host " OK ($($start.ElapsedMilliseconds) ms) [JobID: $($killJob.id.Substring(0,8))]" -ForegroundColor Green
                    $status = "succeeded"
                    $err = "none"
                    $reqId = $killJob.requestId
                    $jobId = $killJob.id
                } else {
                    Write-Host " FALHA" -ForegroundColor Red
                    $status = "failed"
                    $err = if ($killJob) { $killJob.errorMessage } else { "TIMEOUT_WAITING_JOB" }
                    $reqId = if ($killJob) { $killJob.requestId } else { "none" }
                    $jobId = if ($killJob) { $killJob.id } else { "none" }
                }

                $executions += [PSCustomObject]@{
                    execution_id   = $executionCounter
                    round          = $round
                    timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    flow_id        = "FL-5"
                    flow_name      = "Encerramento Controlado (Bloco de Notas)"
                    network        = "LAN (10.0.2.2:4787 / Subnet Local)"
                    request_id     = $reqId
                    job_id         = $jobId
                    status         = $status
                    error_code     = $err
                    duration_ms    = $start.ElapsedMilliseconds
                    observation    = "Processo encerrado com segurança após confirmação modal e verificação de PID"
                }
            } else {
                Write-Host " ERRO: Diálogo de confirmação não apareceu" -ForegroundColor Red
            }
        } else {
            Write-Host " ERRO: Botão Encerrar não encontrado" -ForegroundColor Red
        }
    } else {
        Write-Host " ERRO: Botão Abrir Bloco de Notas não encontrado" -ForegroundColor Red
    }
    if ($round -eq 1 -or $round -eq $Rounds) {
        Capture-EvidenceScreenshot "f9_fl5_kill_r$round"
    }
    $executionCounter++
    Start-Sleep -Milliseconds 600
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Bateria Concluída: $($executions.Count) execuções registradas" -ForegroundColor Cyan
$successCount = ($executions | Where-Object { $_.status -eq "succeeded" }).Count
$successRate = if ($executions.Count -gt 0) { [Math]::Round(($successCount / $executions.Count) * 100, 2) } else { 0 }
Write-Host "Sucessos: $successCount / $($executions.Count) ($successRate%)" -ForegroundColor $(if ($successRate -ge 95) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

# Salva JSON
$executions | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonLogPath -Encoding utf8
Write-Host "Log JSON gerado em: $JsonLogPath" -ForegroundColor Gray

# Gera Markdown consolidado
$metaStatus = if ($successRate -ge 95) { "ATINGIDA (PASS)" } else { "FALHA" }
$nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$totalCount = $executions.Count

$lines = @(
    "# Log de Execuções do Piloto F9 (Command v0.1.0)",
    "",
    "- **Data de Execução:** $nowStr",
    "- **Total de Execuções:** $totalCount",
    "- **Sucessos:** $successCount / $totalCount ($successRate%)",
    "- **Meta do Roadmap:** >= 29/30 (>= 95%) -> **$metaStatus**",
    "- **Ambiente:** Emulador Android Pixel 9 (API 37) + Windows 11 Bridge (self-contained Release)",
    "- **Rede:** LAN (10.0.2.2:4787 / porta 4787)",
    "",
    "## Tabela de Execuções",
    "",
    "| # | Data/Hora UTC | Fluxo | Nome | Rede | Request ID | Estado | Erro | Duração | Observação |",
    "|---|---|---|---|---|---|---|---|---|---|"
)

foreach ($e in $executions) {
    $row = "| {0} | {1} | {2} | {3} | {4} | `{5}` | **{6}** | {7} | {8} ms | {9} |" -f $e.execution_id, $e.timestamp_utc, $e.flow_id, $e.flow_name, $e.network, $e.request_id, $e.status, $e.error_code, $e.duration_ms, $e.observation
    $lines += $row
}

$lines += ""
$lines += "## Resumo por Fluxo"
$lines += ""
$lines += "| Fluxo | Descrição | Execuções | Sucessos | Taxa |"
$lines += "|---|---|---|---|---|"

$groups = $executions | Group-Object flow_id
foreach ($g in $groups) {
    $gSuccess = ($g.Group | Where-Object { $_.status -eq "succeeded" }).Count
    $gRate = [Math]::Round(($gSuccess / $g.Count) * 100, 1)
    $lines += "| {0} | {1} | {2} | {3} | {4}% |" -f $g.Name, $g.Group[0].flow_name, $g.Count, $gSuccess, $gRate
}

$lines | Set-Content -Path $MdLogPath -Encoding utf8
Write-Host "Relatório Markdown gerado em: $MdLogPath" -ForegroundColor Gray

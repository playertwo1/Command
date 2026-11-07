# Roteiro de Homologação Física — Onda v1.5 (Fases I0.6 & H0)

**Versão da Release:** v1.5.0 (`1.5.0-local.20261026.x64` / `1.5.0+14`)  
**Data:** 2026-10-26  
**Status Técnico:** PASS (637 testes automatizados, build release gerado e verificado)  
**Status de Homologação Física:** AGUARDANDO EXECUÇÃO HUMANA NAS 2 MÁQUINAS FÍSICAS (`PENDING_HUMAN`)

---

## 1. Pacotes Oficiais Disponíveis para Teste

Todos os pacotes estão compilados e validados na pasta `dist/`:

| Componente | Arquivo | Tamanho | SHA-256 |
|---|---|---|---|
| **Instalador Windows (Velopack)** | `dist/command-installer/1.5.0-local.20261026.x64/Command-Setup.exe` | 110.98 MB | `522e1d66bbfba576c40f6792a713df7975794c0c1977ec54156b43901e0b6da6` |
| **Bridge Portátil Windows** | `dist/command-bridge-v1.5.0-win-x64.zip` | 91.55 MB | `d6eb550a117d9b49532559199ec896e5da244c5e0da598f1b66e3447be114e4b` |
| **App Android (Release)** | `dist/command-app-v1.5.0.apk` (`Command.apk`) | 74.08 MB | `643f3ee9c4d69f347cb21d3ca36c98421c7035a8d14aae6fbbca235416e00c30` |

*Os hashes podem ser conferidos via `dist/SHA256SUMS-v1.5.0.txt`.*

---

## 2. Pré-requisitos do Teste Físico

1. **PC Primário (Host de Desenvolvimento):**
   - Windows 11 com Bridge Command v1.5.0 em execução (`localhost:4787` e porta de controle `4788`).
2. **PC Secundário (Máquina Física de Validação):**
   - Windows 10/11 limpo ou com uma versão anterior do Command.
   - Conectado na mesma rede local (LAN) ou via Tailscale.
3. **Dispositivo Móvel:**
   - Celular Android com o APK `command-app-v1.5.0.apk` instalado (atualização direta sobre a v1.1.2 para comprovação de preservação de dados).

---

## 3. Roteiro de Testes Passo a Passo (Bateria H0)

### Etapa 1: Instalação e Migração na Segunda Máquina Física (I0.6)
1. Copie `Command-Setup.exe` para a segunda máquina física.
2. (Opcional) Execute a validação assistida no PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File install.ps1 -InstallerPath .\Command-Setup.exe
   ```
3. Verifique se a instalação conclui sem exigir privilégios de Administrador (instalado em `%LocalAppData%\Command\current`).
4. Verifique o ícone do Command na bandeja do sistema (System Tray).
5. Se havia dados de uma instalação anterior, execute o assistente de migração segura na bandeja ou via CLI:
   ```cmd
   Command.exe --migrate-legacy --confirm
   ```
   *Critério de Aceite:* Configurações migradas para `%AppData%\Command` e chaves DPAPI re-cifradas com a entropia do Command, sem perda dos dados originais.

---

### Etapa 2: Pareamento e Painel Multi-PC Paralelo (M0 / M1)
1. No celular Android, abra o app Command v1.5.0.
2. Na aba **Configurações → PCs pareados**, adicione o segundo PC escaneando o QR Code da tela da segunda máquina (ou selecione na lista de descoberta mDNS).
3. Na aba **Status**:
   - Verifique o card **Meus 2 PCs**: ambos os computadores devem aparecer com status **Online**, exibindo CPU, RAM e latência em tempo real simultaneamente.
   - Alterne o seletor de PC-alvo e comprove que o cabeçalho e as ações mudam reativamente para o PC selecionado.

---

### Etapa 3: Controle Remoto — Trackpad e Teclado Virtual (R0 / R1)
1. Selecione o PC-alvo e acesse o card **Controle Remoto (Trackpad)** na StatusPage.
2. **Movimento:** Arraste 1 dedo na tela e verifique o cursor se movendo de forma fluida no PC.
3. **Cliques:** Toque com 1 dedo (clique esquerdo) e toque com 2 dedos ou botão dedicado (clique direito).
4. **Rolagem:** Arraste com 2 dedos para rolar verticalmente uma página ou documento aberto no PC.
5. **Teclado e Atalhos:**
   - Abra a gaveta de atalhos e teste `Win`, `Alt+Tab`, `Esc`.
   - Digite um texto livre (até 500 caracteres) no campo de texto e envie; verifique o texto sendo digitado no bloco de notas no PC.
   - Verifique que o indicador na bandeja do Windows exibe a sessão de controle ativa com o nome do dispositivo.

---

### Etapa 4: Prévia ao Vivo com Toque-para-Clicar (R2)
1. No app móvel, ative a **Prévia ao Vivo** da tela do computador.
2. Comprove a recepção contínua dos frames da tela (stream MJPEG).
3. Ative o modo **Toque-para-Clicar**:
   - Toque em um ícone ou botão visível na prévia do celular.
   - Verifique se o clique Win32 é disparado exatamente nas coordenadas físicas correspondentes na tela do monitor do PC.
4. Bloqueie a sessão do Windows (`Win+L`) e observe que o app exibe imediatamente o banner informativo de tela bloqueada (`423 Locked`), sem tentar contornar a segurança.

---

### Etapa 5: Descoberta Automática mDNS e Troca de Rede (D0)
1. Com o app aberto, desconecte temporariamente o Wi-Fi e ative o Tailscale (ou reconecte na LAN).
2. Verifique se o serviço mDNS / fallback de reconexão detecta o novo IP e restabelece a conexão sem exigir novo pareamento manual.

---

### Etapa 6: Transferência Retomável em Blocos (T0)
1. Na aba de **Transferência de Arquivos**, inicie o envio de um arquivo de teste (~20 MB) para o PC.
2. Durante a transferência (~50%), desligue temporariamente a conexão de rede ou feche o app.
3. Reabra o app e reative a conexão: retome a transferência e confirme que ela continua a partir do último bloco (4 MiB) concluído.
4. No PC, confirme a integridade do arquivo recebido com hash SHA-256 idêntico ao original.

---

### Etapa 7: Desinstalação Limpa com Preservação de Dados (I0.5)
1. Na segunda máquina, encerre o teste executando:
   ```powershell
   powershell -ExecutionPolicy Bypass -File uninstall.ps1
   ```
2. Verifique que os processos foram encerrados e os atalhos removidos.
3. Comprove que a pasta `%AppData%\Command` foi **preservada** para que uma reinstalação futura não perca os perfis pareados.

---

## 4. Tabela de Registro de Evidências

| Item | Descrição do Teste | Resultado Técnico | Resultado Físico | Evidência / Observações |
|---|---|---|---|---|
| **H0.1** | Instalação no 2º PC via `Command-Setup.exe` sem UAC | PASS | `PENDING_HUMAN` | |
| **H0.2a** | Telemetria e métricas simultâneas nos 2 PCs | PASS | `PENDING_HUMAN` | |
| **H0.2b** | Ação e encerramento seguro no PC selecionado | PASS | `PENDING_HUMAN` | |
| **H0.2c** | Trackpad com clique esquerdo/direito e rolagem | PASS | `PENDING_HUMAN` | |
| **H0.2d** | Digitação de texto livre (≤500 chars) sanitizado | PASS | `PENDING_HUMAN` | |
| **H0.2e** | Prévia ao vivo MJPEG com Toque-para-Clicar | PASS | `PENDING_HUMAN` | |
| **H0.2f** | Bloqueio de controle em tela bloqueada (`Win+L`) | PASS | `PENDING_HUMAN` | |
| **H0.2g** | Descoberta mDNS `_command._tcp` e reconexão | PASS | `PENDING_HUMAN` | |
| **H0.2h** | Transferência retomável em blocos (4 MiB) | PASS | `PENDING_HUMAN` | |
| **H0.2i** | Migração segura de dados legados (I0.3c) | PASS | `PENDING_HUMAN` | |
| **H0.2j** | Desinstalação com preservação de dados (I0.5) | PASS | `PENDING_HUMAN` | |

---

## 5. Registro de Aceite Final

- **Data da Homologação:** _____ / _____ / 2026
- **Ambiente:**
  - PC 1 (Primário): ________________________ (Windows 11)
  - PC 2 (Secundário): ________________________ (Windows 10/11)
  - Mobile: ________________________ (Android _____)
- **Decisão do Proprietário:** [  ] APROVADO (`PASS_HUMAN`)  /  [  ] AJUSTES SOLICITADOS
- **Assinatura / Comentários:** __________________________________________________

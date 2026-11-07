<div align="center">

<img src="website/landing/logo.svg" alt="Command Logo" width="96" height="96">

# Command

**Controle o PC com Windows e acompanhe o hardware pelo aplicativo Android.**

[![Licenses: Apache 2.0 / GPL 3.0](https://img.shields.io/badge/Licenses-Apache%202.0%20%2F%20GPL%203.0-green.svg?style=for-the-badge)](docs/LICENSES.md)

<br/>

<img src="docs/assets/command-preview.jpg" alt="Command Preview" width="100%" style="border-radius: 12px;">

</div>

---

## 🎯 Sobre o Command

O **Command** conecta o aplicativo Android ao serviço de bandeja do Windows pela rede local. Ele oferece controle de ações autorizadas, telemetria, perfis e integrações; as licenças e atribuições das bases utilizadas estão em [`docs/LICENSES.md`](docs/LICENSES.md) e [`research/UPSTREAM.md`](research/UPSTREAM.md).

### ✨ O que o projeto oferece:
- **Recursos de controle:**
  - ⌨️ Teclas de atalho e macros graváveis pelo teclado.
  - 🪟 Troca rápida de dispositivos de áudio, bloquear tela, suspender.
  - ⏱️ Timers, cronômetros, pomodoros e contadores integrados.
  - 🎮 Atalhos de jogos da Steam com capa automática.
  - 🔊 Mixer de áudio por aplicativo em tempo real.
  - 💬 Integração completa com Discord (mute, ensurdecer, canais, soundboard).
  - 🎥 Controle avançado de OBS Studio via WebSocket (cenas, gravação, transmissão, áudio).
  - 💡 Casa inteligente via Home Assistant e Tuya / Smart Life.
  - 🎧 Spotify, Twitch e YouTube com status ao vivo.
  - 🖥️ Gerenciamento e troca dinâmica entre múltiplos PCs.
  - 📱 Pareamento seguro por QR code e chave de API local (`command://pair`).
- **Recursos adicionais do Command:**
  - 📊 Telemetria de CPU, RAM, disco, GPU, bateria e temperatura. Se o LibreHardwareMonitor não ler o sensor, a CPU cai para a zona ACPI e a GPU para o driver NVIDIA ou AMD, sem pedir administrador.
  - 🌡️ No card dos dois PCs, a temperatura fica verde até 60°C, âmbar até 80°C e vermelha acima. Acima de 85°C o card avisa.
  - 🖥️ Dois PCs ao mesmo tempo, com o PC-alvo escolhido no cartão.
  - 🖱️ Trackpad, teclado e prévia da tela em resolução cheia.
  - 🎛️ Stream Deck com cor HEX, ícone PNG/SVG/GIF, grade de 2×2 a 8×6, fundo e widgets de CPU, RAM, GPU, temperatura e mídia.
  - ⚡ Bloquear, suspender, desligar e reiniciar, sempre com confirmação. Wake-on-LAN e Modo Dock continuam no mesmo card.
  - 🔄 Rotinas editáveis, com atalhos da lista fechada, mídia, pausa e apps do catálogo.
  - 🎨 Tema Amethyst (`#13101B`, `#1E1829`, `#A78BFA`).
  - 🌐 Configurador web em `http://localhost:4787`.
  - 🛡️ Papel por dispositivo e guardião de PIN/biometria.
  - 🔐 Backup AES-256-GCM e pacotes conferidos por SHA-256.

### Baixar a 1.6.1

Os arquivos estão na [release 1.6.1](https://github.com/playertwo1/Command/releases/tag/command-v1.6.1).

| Arquivo | Uso |
|---|---|
| `Command-Setup.exe` | Instalador do PC, Windows x64. Fica na bandeja. Não traz assinatura Authenticode. |
| `command-app-v1.6.1.apk` | App Android, versão 1.6.1 (código 16). O certificado é o mesmo da 1.6.0. |

Os hashes estão em `SHA256SUMS-v1.6.1.txt` na mesma release. Depois de instalar o PC, clique com o botão direito no ícone da bandeja, escolha parear e leia o QR no celular. Os dois aparelhos precisam estar na mesma rede.

---

## 🧭 Navegação rápida do projeto

| Pergunta | Arquivo |
|---|---|
| Onde paramos e qual é a próxima ação? | [STATE.md](STATE.md) |
| Qual é o produto, escopo e metas? | [PROJECT.md](PROJECT.md) |
| Quais são os gates e a sequência oficial? | [ROADMAP.md](ROADMAP.md) |
| Qual é a referência visual e design tokens? | [DESIGN.md](DESIGN.md) e [referências do Stitch](references/stitch/README.md) |
| Quais decisões de arquitetura foram tomadas? | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Como registrar evidência e critérios de aceite? | [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) |
| Quais regras os agentes e desenvolvedores seguem? | [AGENTS.md](AGENTS.md) |
| Documentação detalhada do Command? | [website/docs/pt/](website/docs/pt/) ou [website/docs/en/](website/docs/en/) |

---

## 🧩 Arquitetura do repositório

```text
CommandPC/              Backend C# (.NET 8 WinForms Tray + ASP.NET Core + SignalR + API REST)
app/                    Aplicativo móvel e configurador web em Flutter (Dart)
tests/Command.Tests/    Suíte de testes unitários e de integração do backend
scripts/                Scripts de build, empacotamento e deploy do frontend web
website/                Documentação MkDocs e site institucional (EN/PT)
docs/                   Decisões de arquitetura (ADRs), roadmap, manual e checklists
contracts/              Especificações OpenAPI e schemas da API
```

```mermaid
flowchart TD
    subgraph MobileApp["📱 Aplicativo Android (Flutter / Dart)"]
        UI_Status["Status Page<br/>(Telemetria em Tempo Real)"]
        UI_Deck["Stream Deck Page<br/>(Grade de Ações e Atalhos)"]
        UI_Audio["Mixer & Audio Page<br/>(Controle de Volume por App)"]
        Theme["Amethyst Dark Theme<br/>(#050408, #13101B, #A78BFA)"]
    end

    subgraph BridgePC["🖥️ Windows Bridge (.NET 8 Tray & Kestrel API)"]
        API["ASP.NET Core REST API<br/>(Porta 4787 / X-Api-Key)"]
        Hub["SignalR DeckHub<br/>(Eventos ao Vivo e Sync)"]
        Pairing["Pairing Service<br/>(QR Code command://pair + DPAPI)"]
        Monitor["SystemMonitorService<br/>(Coleta Contínua a cada 1s)"]
        ActionExec["ActionExecutorService<br/>(Execução com Allowlist e Confirmação)"]
    end

    subgraph WindowsOS["🪟 Windows OS & Hardware Subsystems"]
        HW_Counters["Performance Counters & P/Invoke<br/>(CPU, RAM GlobalMemoryStatusEx, GPU Engine)"]
        HW_Storage["Storage & Uptime<br/>(DriveInfo GetDiskFreeSpaceEx, TickCount64)"]
        Audio_Core["NAudio / Wasapi<br/>(MMDeviceEnumerator & Per-App Sessions)"]
        Input_Core["SendInput & Win32 API<br/>(Atalhos, Janelas, Processos)"]
    end

    subgraph Integrations["🔌 Ecossistema de Integrações"]
        OBS["OBS Studio (WebSocket v5)"]
        Discord["Discord (Local RPC IPC)"]
        Tuya["Tuya / Smart Life (Local Protocol)"]
        Soundboard["Soundboard (MyInstants + VB-Cable)"]
        Media["Mídia Windows (WinRT)"]
    end

    %% Conexões
    UI_Status <--> |"SignalR ReceiveSystemStats & GET /api/metrics"| Hub
    UI_Deck <--> |"REST /api/actions & /api/deck"| API
    UI_Audio <--> |"REST /api/mixer & SignalR"| API

    Monitor --> HW_Counters
    Monitor --> HW_Storage
    Monitor --> |"Broadcast Stats"| Hub

    ActionExec --> Input_Core
    ActionExec --> Audio_Core
    ActionExec --> Integrations
```

---

## 🛠️ Compilação e testes locais

O repositório possui ferramentas e SDKs homologados para execução imediata:

### Backend (.NET 8)
```powershell
# Executar a suíte de testes do backend
research\upstream\.tools\dotnet-8.0.426\dotnet.exe test Command.sln

# Executar o backend em modo Tray
research\upstream\.tools\dotnet-8.0.426\dotnet.exe run --project CommandPC\CommandPC.csproj

# Executar o backend em modo headless
research\upstream\.tools\dotnet-8.0.426\dotnet.exe run --project CommandPC\CommandPC.csproj -- --headless
```

### Frontend (Flutter)
```powershell
cd app

# Obter dependências
..\research\upstream\.tools\flutter\bin\flutter.bat pub get

# Executar testes
..\research\upstream\.tools\flutter\bin\flutter.bat test
```

---

## 📄 Licença e atribuição

As licenças e os créditos dos componentes de origem estão documentados em [`docs/LICENSES.md`](docs/LICENSES.md) e [`research/UPSTREAM.md`](research/UPSTREAM.md). O backend segue Apache 2.0 ([`LICENSE`](LICENSE)) e o aplicativo Flutter segue GPL 3.0 ([`app/LICENSE`](app/LICENSE)).

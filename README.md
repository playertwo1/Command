<div align="center">

<img src="website/landing/logo.svg" alt="Command Logo" width="96" height="96">

# Command

**Controle de PC e telemetria de hardware para Windows via aplicativo Android/Flutter, baseado no DroidDeck.**

[![Upstream DroidDeck](https://img.shields.io/badge/upstream-DroidDeck%20v1.9.1-blue?style=for-the-badge)](https://github.com/ggfto/DroidDeck)
[![License: Apache 2.0 / GPL 3.0](https://img.shields.io/badge/License-Apache%202.0%20%2F%20GPL%203.0-green.svg?style=for-the-badge)](LICENSE)

</div>

---

## 🎯 Sobre o Command

O **Command** é uma solução de controle e telemetria de PC pessoal para Windows através de um aplicativo móvel Android. Ele é desenvolvido como um **in-tree fork ativo do [DroidDeck v1.9.1](https://github.com/ggfto/DroidDeck)**, combinando todo o ecossistema comprovado do DroidDeck com as capacidades avançadas de telemetria e o design Amethyst Dark do Command.

### ✨ O que o projeto oferece:
- **Base DroidDeck v1.9.1 completa:**
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
  - 📱 Pareamento seguro e imediato via QR code e chave de API local (`droiddeck://pair`).
- **Extensões Command:**
  - 📊 Telemetria detalhada de hardware (CPU, Memória RAM, Discos, Uptime, GPU).
  - 🎨 Tema visual Command Amethyst Dark e cartões de status do sistema.
  - 🤖 Suporte arquitetural para o agente de IA opcional Hermes.

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
| Documentação detalhada do DroidDeck? | [website/docs/pt/](website/docs/pt/) ou [website/docs/en/](website/docs/en/) |

---

## 🧩 Arquitetura do repositório

```text
DroidDeck/             Backend C# (.NET 8 WinForms Tray + ASP.NET Core + SignalR + API REST)
app/                   Aplicativo móvel e configurador web em Flutter (Dart)
tests/DroidDeck.Tests/ Suíte de testes unitários e de integração do backend
scripts/               Scripts de build, empacotamento e deploy do frontend web
website/               Documentação MkDocs e site institucional (EN/PT)
docs/                  Decisões de arquitetura (ADRs), roadmap, manual e checklists
contracts/             Especificações OpenAPI e schemas da API
```

---

## 🛠️ Compilação e testes locais

O repositório possui ferramentas e SDKs homologados para execução imediata:

### Backend (.NET 8)
```powershell
# Executar a suíte de testes do backend
research\upstream\.tools\dotnet-8.0.426\dotnet.exe test DroidDeck.sln

# Executar o backend em modo Tray
research\upstream\.tools\dotnet-8.0.426\dotnet.exe run --project DroidDeck

# Executar o backend em modo headless
research\upstream\.tools\dotnet-8.0.426\dotnet.exe run --project DroidDeck -- --headless
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

O Command é derivado do projeto [DroidDeck](https://github.com/ggfto/DroidDeck), mantido originalmente por @ggfto.
- O backend .NET é distribuído sob a licença [Apache 2.0](LICENSE).
- O aplicativo Flutter é distribuído sob a licença [GPL 3.0](LICENSE).

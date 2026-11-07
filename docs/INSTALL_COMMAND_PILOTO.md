# Instalador local do Command — piloto

Registro histórico do piloto. Desde 2026-11-06, o executável foi renomeado para `Command.exe`; veja o guia atual em `docs/INSTALL.md`.

O script `scripts/build-command-installer.ps1` gera um `Command-Setup.exe` autocontido para Windows x64 com Velopack 1.2.161. Ele compila o configurador Web Flutter da árvore atual, empacota o Bridge .NET e grava SHA-256 e manifesto ao lado do setup. O destino é `dist/command-installer/<versao>/`.

Exemplo, com .NET 8 SDK e Flutter disponíveis:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-command-installer.ps1 -Version 1.1.0-local.20261024.x64
```

Naquele piloto, o PackId era `CommandPC` e o executável ainda usava a identidade anterior para manter os hooks Velopack existentes. O Command usa `%LocalAppData%\Command` e `%AppData%\Command`, com logs `Command.log`; os dados anteriores permaneciam separados e não eram importados automaticamente.

O setup daquele piloto não consultava releases anteriores. Atualizações remotas ficavam desativadas enquanto o repositório Command era privado. O manifesto registra estado da assinatura; um build local pode não ter assinatura Authenticode. O instalador não contorna UAC nem SmartScreen. Se o Windows bloquear ou mostrar um aviso de editor não verificado, interrompa a instalação e peça uma versão assinada/aprovada; não use uma opção de bypass.

A instalação é por usuário. No primeiro início, o Bridge oferece liberar TCP 4787 e UDP 7573 somente para a sub-rede local, pedindo consentimento e UAC legítimo. O app também pode registrar inicialização automática sem substituir entradas preexistentes. Não execute duas instalações do Bridge ao mesmo tempo no mesmo PC, pois ambas usam a porta 4787. A migração com consentimento, validação de segredos e cópia de recuperação foi concluída em I0.3c; mantenha os dados antigos até confirmar que a migração terminou.

Este artefato também está disponível como [prerelease privada no GitHub](https://github.com/playertwo1/Command/releases/tag/command-v1.1.0-local.20261024.x64); o repositório permanece privado e o atualizador remoto continua desativado. O manifesto registra que o build veio de uma árvore suja; o código-fonte associado ao tag não reproduz exatamente o binário. Antes de qualquer distribuição pública ou mais ampla, continuam obrigatórios os gates I0.1, I0.2, I0.5, I0.6 e I0.7 do roadmap.

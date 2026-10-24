# Command para Android 1.1.1 — piloto M1 Multi-PC

Este APK piloto adiciona o painel **Meus 2 PCs** e a seleção explícita do PC-alvo. Ele se conecta a até duas instalações da Command Bridge para Windows.

## Instalar ou atualizar

- Arquivo: `command-app-v1.1.1.apk`
- Versão Android: `1.1.1` (versionCode `12`)
- Requer Android 7.0 ou posterior.
- O pacote e a chave de assinatura são compatíveis com o APK Command v1.1.0. Instale por cima para preservar os perfis pareados e os dados locais.
- Se o Android indicar conflito de assinatura ou pedir para desinstalar o app existente, cancele e informe o erro; desinstalar pode apagar os dados locais.

## Parear e selecionar o segundo PC

1. Instale e abra a Command Bridge em cada PC Windows. Deixe ambos acessíveis pela rede.
2. Em cada Bridge, abra **Parear dispositivo (QR)**.
3. No Android, abra **Configurações** e leia o QR de cada PC. Cada PC deve aparecer em **PCs pareados**.
4. No menu do PC que não está em foco, escolha **Conectar em paralelo**. O limite é de dois PCs simultâneos.
5. Volte à tela **Status** e toque no cartão do PC em **Meus 2 PCs** para definir o alvo.

Instalar a Bridge nos PCs não faz o pareamento automaticamente. O QR é explícito e cada perfil precisa estar salvo no app.

## Escopo e validação

O app encaminha ao PC escolhido o catálogo de aplicativos, ações suportadas, rotinas, energia e transferências. Ações destrutivas continuam exigindo confirmação. Não há execução arbitrária de shell.

Esta é uma prerelease privada para validação. A instalação e o pareamento em duas máquinas físicas e o aceite visual ainda estão pendentes. Atualizações automáticas do piloto estão desativadas.

## Verificação

Consulte `SHA256SUMS-v1.1.1.txt` anexado à release para conferir a integridade do APK.

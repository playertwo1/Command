# Guia de Instalação, Execução e Pareamento — Command v1.1.0

Este guia descreve os procedimentos exatos para instalação, execução na sessão do usuário, configuração de firewall, pareamento, parada, revogação e desinstalação dos pacotes do Command.

---

## 1. Pacotes Oficiais da Versão v1.1.0

Os pacotes oficiais de produção foram gerados a partir do branch `main`:

| Componente | Arquivo | Algoritmo | Hash Criptográfico |
|---|---|---|---|
| **Windows Bridge (c/ Web Configurator `wwwroot/`)** | `dist/command-bridge-v1.1.0-win-x64.zip` | SHA-256 | `38e630aabfcde2b1400c0f8717b0c3b590ae3f8a5109b8973b6f1f627dd99aff` |
| **Android App (Release)** | `dist/command-app-v1.1.0.apk` | SHA-256 | `56827877a0f2643354578730faa673358a64f08bdc73df829c10e135e7af7be8` |

> [!NOTE]
> Para verificar a integridade antes de instalar:
> ```powershell
> Get-FileHash dist\command-bridge-v1.1.0-win-x64.zip, dist\command-app-v1.1.0.apk -Algorithm SHA256
> ```

---

## 2. Requisitos de Sistema

### PC Windows (Bridge)
- **Sistema Operacional:** Windows 10 ou Windows 11 x64 (Build 17763 ou superior).
- **Runtime:** [.NET 8.0 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0) x64.
- **Permissões:** Execução na **sessão interativa do usuário**. Não requer privilégios de administrador (UAC).
- **Rede:** Conexão Wi-Fi ou cabo na mesma rede local (LAN) do aparelho celular.

### Dispositivo Móvel (Android)
- **Sistema Operacional:** Android 10.0+ (API 29+). Testado e otimizado para telas AMOLED (Galaxy S25 Ultra).
- **Conectividade:** Wi-Fi ativo na mesma sub-rede do PC Windows.

---

## 3. Instalação e Execução do Windows Bridge

### Opção A: Instalador Direto (`Command-Setup.exe` / Velopack — Recomendado)
1. Baixe o instalador `Command-Setup.exe` da release oficial.
2. Dê um duplo clique em `Command-Setup.exe` para instalar na sessão do usuário (`%LocalAppData%\CommandPC`).
3. Não requer elevação de privilégios de administrador (UAC).
4. O instalador cria o atalho no menu Iniciar, registra o desinstalador no Painel de Controle e inicia o Command na bandeja do Windows (System Tray).

### Opção B: Instalação Assistida com Verificação Criptográfica (`install.ps1`)
Para validar a integridade criptográfica SHA-256 e assinatura Authenticode antes de executar:
```powershell
.\install.ps1
```
Ou especificando versão / arquivo direto:
```powershell
.\install.ps1 -SourcePath "dist\command-installer\1.1.0-local.20261024.x64\Command-Setup.exe"
```
> [!NOTE]
> O script calcula o hash SHA-256 do executável contra o manifesto oficial (`Command-Setup.manifest.json` ou `.sha256`) e aborta com erro fatal `CHECKSUM_MISMATCH` em caso de divergência ou arquivo adulterado.

### Opção C: Pacote Portátil (`.zip`, sem instalar)
1. Descompacte `Command-win-x64.zip` em um diretório do usuário (ex: `C:\CommandBridge`).
2. Execute `DroidDeck.exe` diretamente ou via linha de comando (`.\DroidDeck.exe --headless` para modo sem bandeja).

### Passo Adicional: Firewall do Windows (Apenas Rede Privada)
Caso a rede local bloqueie conexões de outros dispositivos, o Command oferece a liberação na primeira execução ou pelo menu da bandeja. Para configurar manualmente:
```powershell
New-NetFirewallRule -DisplayName "Command Bridge LAN" -Direction Inbound -LocalPort 4787 -Protocol TCP -Action Allow -Profile Private
New-NetFirewallRule -DisplayName "Command Bridge Control" -Direction Inbound -LocalPort 4788 -Protocol TCP -Action Allow -Profile Private
New-NetFirewallRule -DisplayName "Command Bridge Discovery" -Direction Inbound -LocalPort 7573 -Protocol UDP -Action Allow -Profile Private
```
> [!IMPORTANT]
> Nunca crie regras liberando as portas 4787, 4788 ou 7573 para redes públicas.

---

## 4. Instalação do Aplicativo Android

### Via Download Direto (Sideload — APK Release)
1. Transfira o arquivo `dist/Command.apk` para o armazenamento do celular.
2. Abra o gerenciador de arquivos do celular e toque no APK.
3. Permita a instalação de fontes desconhecidas para o instalador e confirme.

### Via ADB (Desenvolvimento / Emulador / USB)
Com o aparelho conectado via USB e com depuração USB habilitada:
```powershell
adb install -r dist/Command.apk
```

---

## 5. Pareamento Seguro e Primeiro Acesso

1. No PC com o Bridge em execução, abra o navegador e acesse:
   ```
   http://localhost:4787
   ```
2. Na aba **Pareamento** do configurator, será gerado um QR Code contendo o payload seguro `droiddeck://pair` com endereço, porta e API Key gerada protegida por **DPAPI** (Data Protection API do Windows).
3. No celular Android, abra o aplicativo **Command**.
4. Toque no ícone de pareamento / configurações e escaneie o QR Code exibido na tela do PC (ou digite manualmente o endereço IP e a chave de API fornecida).
5. O aplicativo móvel salvará as credenciais no armazenamento seguro local e estabelecerá a conexão de telemetria SignalR e HTTP.
6. A tela inicial (Status) passará a exibir o badge **Online** verde e as métricas de hardware em tempo real (CPU, RAM, Disco, GPU, Rede e Uptime).

---

## 6. Parada / Encerramento do Bridge

- **Pela Bandeja do Windows:** Clique com o botão direito no ícone do Command Bridge no System Tray e selecione **Sair** (Exit).
- **Por Linha de Comando:** Se estiver rodando no terminal, pressione `Ctrl + C` ou utilize:
  ```powershell
  Stop-Process -Name DroidDeck -Force
  ```
- O encerramento fecha imediatamente os ouvintes de rede na porta 4787 e encerra conexões SignalR.

---

## 7. Revogação de Acesso e Segurança

Se o aparelho for perdido, substituído ou o acesso precisar ser revogado:
1. **Revogação pelo PC (Autoritativa):**
   - Acesse o configurator web em `http://localhost:4787` e toque em **Revogar Dispositivos** / **Gerar Nova Chave**.
   - Ou encerre o Bridge e remova o arquivo de credenciais salvas em `%LocalAppData%\DroidDeck\settings.json` e `%LocalAppData%\DroidDeck\devices.json`.
   - Ao iniciar novamente, o Bridge gerará novas credenciais DPAPI e rejeitará qualquer conexão antiga com código `401 Unauthorized`.
2. **Revogação pelo Celular:**
   - No app Command, abra a aba **Configurações** e toque em **Desconectar / Limpar Pareamento**.
   - As chaves de API salvas localmente no celular serão apagadas da memória e do storage.

---

## 8. Desinstalação e Limpeza (I0.5)

### Opção A: Desinstalação Padrão pelo Windows
1. Abra as **Configurações do Windows** ➔ **Aplicativos** ➔ **Aplicativos Instalados** (ou Painel de Controle).
2. Localize **Command** e selecione **Desinstalar**.
3. O desinstalador Velopack removerá os binários e atalhos na sessão do usuário.
4. **Preservação de Dados:** Por padrão, suas configurações, perfis e credenciais em `%AppData%\Command` e `%LocalAppData%\Command` são preservados intactos para reinstalações futuras.

### Opção B: Desinstalação Assistida (`uninstall.ps1`)
Para remover atalhos, processos, regras de firewall e desinstalar em um único comando:
```powershell
.\uninstall.ps1
```
Para também apagar permanentemente todas as pastas de dados e configurações do Command:
```powershell
.\uninstall.ps1 -PurgeData
```

---

## 9. Assinatura Authenticode, SmartScreen e Recuperação de Versão

### Assinatura Digital e SmartScreen
- **Piloto Local / Builds de Desenvolvimento:** São empacotados com status Authenticode `NotSigned` (sem certificado comercial EV de alto custo).
- Ao executar pela primeira vez, o Windows Defender SmartScreen pode exibir o aviso azul *"O Windows protegeu o seu computador"*.
- **Como prosseguir:** Clique em **Mais informações** ➔ **Executar assim mesmo**. O SmartScreen não é contornado pelo instalador; a decisão de confiança permanece estritamente nas mãos do usuário.
- A integridade criptográfica deve sempre ser validada pelo checksum SHA-256 oficial do release antes de prosseguir.

### Atualização e Recuperação (Rollback)
- O Command Bridge utiliza o gerenciador Velopack com estratégia de isolamento por versão em `%LocalAppData%\CommandPC\current`.
- Caso uma nova versão apresente instabilidade:
  1. Encerre o Command na bandeja.
  2. Execute o instalador `Command-Setup.exe` da versão anterior compatível desejada.
  3. O instalador substitui os binários da versão atual e preserva intactas as pastas de dados em `%AppData%\Command` e `%LocalAppData%\Command`.
  4. Suas credenciais DPAPI, pares autorizados e configurações continuarão funcionando sem necessidade de novo pareamento.

---

### No Android (Desinstalação)
- Pressione e segure o ícone do aplicativo **Command** na gaveta de aplicativos e selecione **Desinstalar**.

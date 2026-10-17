# Guia de Instalação, Execução e Pareamento — Command v0.1.0

Este guia descreve os procedimentos exatos para instalação, execução na sessão do usuário, configuração de firewall, pareamento, parada, revogação e desinstalação dos pacotes do Command.

---

## 1. Pacotes Oficiais da Versão v0.1.0

Os pacotes de teste foram gerados a partir do branch `main` (`1d7091d`):

| Componente | Arquivo | Algoritmo | Hash Criptográfico |
|---|---|---|---|
| **Windows Bridge** | `dist/command-bridge-v0.1.0-win-x64.zip` | SHA-256 | `0E07436E4D310DD21C7E7CCA06FE3A55F3C1231F85524A62D9CFD85DDD4D32E7` |
| **Android App** | `dist/command-app-v0.1.0-debug.apk` | SHA-256 | `537D38913DB4E6DB36C85CFB85488C3BEC46B6F201AC2D3423E1DA649784E975` |

> [!NOTE]
> Para verificar a integridade antes de instalar:
> ```powershell
> Get-FileHash dist\command-bridge-v0.1.0-win-x64.zip, dist\command-app-v0.1.0-debug.apk -Algorithm SHA256
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

### Passo 1: Extração
1. Descompacte `command-bridge-v0.1.0-win-x64.zip` em um diretório de sua escolha dentro do perfil de usuário (exemplo: `C:\Users\<usuario>\AppData\Local\Programs\CommandBridge` ou `C:\CommandBridge`).
2. Não utilize pastas de sistema que exijam elevação de privilégios (`Program Files`).

### Passo 2: Execução
O Bridge pode ser iniciado de duas formas:
- **Modo Bandeja (Padrão com interface gráfica):** Dê um duplo clique em `DroidDeck.exe`. O ícone aparecerá na área de notificação do Windows (System Tray).
- **Modo Headless (Sem ícone na bandeja, ideal para scripts ou background):**
  ```powershell
  .\DroidDeck.exe --headless
  ```

O Bridge vinculará o servidor Kestrel à porta **4787** (ex: `http://localhost:4787` e `http://<IP_DO_PC>:4787`).

### Passo 3: Firewall do Windows (Apenas Rede Privada)
Caso a rede local bloqueie conexões de outros dispositivos, adicione uma regra de entrada restrita ao perfil **Privado** com o comando PowerShell (requer confirmação explícita):
```powershell
New-NetFirewallRule -DisplayName "Command Bridge LAN" -Direction Inbound -LocalPort 4787 -Protocol TCP -Action Allow -Profile Private
```
> [!IMPORTANT]
> Nunca crie regras liberando a porta 4787 para redes públicas.

---

## 4. Instalação do Aplicativo Android

### Via ADB (Desenvolvimento / Emulador / USB)
Com o aparelho conectado via USB e com depuração USB habilitada:
```powershell
adb install -r dist/command-app-v0.1.0-debug.apk
```

### Via Download Direto (Sideload)
1. Transfira o arquivo `dist/command-app-v0.1.0-debug.apk` para o armazenamento do celular.
2. Abra o gerenciador de arquivos do celular e toque no APK.
3. Permita a instalação de fontes desconhecidas para o instalador e confirme.

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

## 8. Desinstalação Limpa

### No Windows
1. Encerre o processo `DroidDeck.exe`.
2. Exclua a pasta descompactada do Bridge.
3. Para remover completamente logs, jobs e temporários do sistema, exclua o diretório de dados:
   ```powershell
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\DroidDeck"
   ```
4. Se foi criada a regra de firewall, remova-a com:
   ```powershell
   Remove-NetFirewallRule -DisplayName "Command Bridge LAN" -ErrorAction SilentlyContinue
   ```

### No Android
- Pressione e segure o ícone do aplicativo **Command** na gaveta de aplicativos e selecione **Desinstalar**.

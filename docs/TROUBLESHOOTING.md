# Guia de Diagnóstico e Limitações — Command (Troubleshooting)

Este documento reúne diagnósticos, resoluções de problemas comuns e limites operacionais do sistema Command v0.1.0 (Android e Windows Bridge).

---

## 1. Conectividade e Rede

### Sintoma: Aplicativo exibe badge vermelho "Offline" ou banner "Command Bridge Desconectado"
- **Causas prováveis:**
  1. O processo `DroidDeck.exe` no PC não está em execução ou foi encerrado.
  2. O endereço IP do PC na rede local foi alterado pelo roteador (DHCP dinâmico).
  3. O Firewall do Windows ou antivírus de terceiros está bloqueando conexões de entrada na porta TCP `4787`.
  4. O roteador Wi-Fi está com a opção "Isolamento de Ponto de Acesso" (AP Isolation / Client Isolation) ativada, impedindo a comunicação direta entre o smartphone e o computador.
- **Passos para resolução:**
  1. No PC, verifique se o processo está ativo na bandeja do sistema ou no Gerenciador de Tarefas (`DroidDeck.exe`). Se necessário, reinicie o executável.
  2. Abra o terminal no PC e execute `ipconfig` para verificar seu endereço IPv4 local atual (ex: `192.168.1.150`).
  3. No app Command, verifique se o endereço configurado coincide com o IP atual do PC. Se o IP mudou, atualize o endereço nas configurações do app ou configure uma reserva de IP estático no roteador.
  4. Certifique-se de que a rede local do Windows está configurada como **Rede Privada** (Configurações do Windows -> Rede e Internet -> Propriedades da conexão -> Perfil de rede privada).
  5. Adicione a regra de liberação de porta via PowerShell (se ainda não o fez):
     ```powershell
     New-NetFirewallRule -DisplayName "Command Bridge LAN" -Direction Inbound -LocalPort 4787 -Protocol TCP -Action Allow -Profile Private
     ```
  6. No celular, toque no botão **Reconectar** no topo da tela para restabelecer a conexão SignalR e o polling de telemetria sem precisar reiniciar o aplicativo.

---

## 2. Limitações de Rede e Acesso Remoto (Tailscale / VPN)

- **Suporte LAN (Padrão MVP):** O Command opera prioritariamente na rede local (mesma sub-rede Wi-Fi).
- **Acesso Externo via Tailscale:**
  - Se o usuário possuir Tailscale instalado no PC e no celular, é possível conectar remotamente apontando o app para o endereço IP do PC no Tailscale (ex: `100.x.y.z:4787`).
  - Todas as requisições continuam sendo rigorosamente autenticadas via cabeçalho `X-Api-Key` e com validação de `DeviceId`.
  - Caso o Tailscale não esteja instalado ou configurado no ambiente, esta capacidade é classificada formalmente como **NOT_RUN**, limitando o suporte oficial da v0.1.0 à rede local.

---

## 3. Captura de Tela Manual (FL-3)

### Erro: Código 423 Locked ("SESSION_LOCKED")
- **Causa:** A área de trabalho do Windows está bloqueada (atalho `Win + L`), o usuário realizou logoff ou uma caixa de diálogo do Controle de Conta de Usuário (UAC) do Windows está em tela cheia segura (`Secure Desktop`).
- **Política de Segurança:** O Command utiliza a API Win32 nativa `OpenInputDesktop` e respeita a fronteira de segurança do sistema operacional. O software **nunca** tenta contornar bloqueios de tela ou burlar proteções de sessão do Windows.
- **Solução:** Acesse o PC fisicamente, desbloqueie a tela com sua senha/PIN e toque novamente em "Capturar Tela Agora" no aplicativo móvel.

### Erro: Código 410 Gone ("SCREENSHOT_EXPIRED")
- **Causa:** Screenshots manuais possuem tempo de vida estrito de 10 minutos no Bridge (`%LocalAppData%\DroidDeck\screenshots`) por motivos de privacidade e segurança.
- **Solução:** Solicite uma nova captura sob demanda pelo aplicativo.

---

## 4. Ações Autorizadas e Execução de Processos (FL-1, FL-2, FL-5)

### Erro: "App não autorizado ou não encontrado" (Código 404 / 403)
- **Causa:** O aplicativo não aceita caminhos executáveis arbitrários ou comandos de shell enviados pelo celular. Apenas identificadores cadastrados localmente no PC (`AppCatalogService.cs`) são permitidos:
  - `obsidian` (Obsidian Vault)
  - `orbit` (Projeto Orbit no VS Code / Explorer)
  - `test_notepad` (Bloco de Notas de teste)
- **Solução:** Para incluir novos aplicativos no catálogo, a configuração deve ser feita exclusivamente de forma física e local no PC.

### Erro: "Não foi possível encerrar o processo" ou "Processo não encontrado"
- **Causa:** O processo alvo já foi fechado pelo usuário no Windows, ou o identificador PID foi reciclado pelo sistema operacional.
- **Política de Segurança:** O Command valida tanto o PID quanto o horário exato de início (`StartTimeUtc`) para garantir que processos alheios ou de outros usuários nunca sejam finalizados por engano.

### Princípio de Não-Retry Automático
- Em conformidade com o `ROADMAP.md`, mutações que falharem por timeout ou perda momentânea de conexão **nunca** são reexecutadas automaticamente em segundo plano. O usuário sempre recebe feedback visual claro na barra de avisos (SnackBar) e deve confirmar nova tentativa caso deseje.

---

## 5. Transferência de Arquivos (FL-4)

### Erro: Código 409 Conflict ("FILE_ALREADY_EXISTS")
- **Causa:** Um arquivo com o mesmo nome já existe na pasta autorizada (`inbound` ou `outbound`).
- **Solução:** O sistema previne sobrescrita acidental de dados. Renomeie o arquivo no celular antes do envio ou remova o arquivo existente no PC.

### Erro: Código 413 Payload Too Large ("FILE_TOO_LARGE")
- **Causa:** O arquivo selecionado ultrapassa o limite máximo de 100 MiB estipulado para a versão MVP.

### Erro: Código 400 Bad Request ("CHECKSUM_MISMATCH")
- **Causa:** O hash SHA-256 verificado após a escrita do arquivo temporário `.tmp` divergiu do hash informado pelo cliente na requisição.
- **Solução:** O arquivo incompleto ou corrompido é sumariamente excluído e não é disponibilizado na pasta de destino. Verifique a estabilidade da conexão Wi-Fi e realize uma nova tentativa.

### Erro: Código 400 Bad Request ("INVALID_EXTENSION")
- **Causa:** Tentativa de enviar arquivos com extensões executáveis bloqueadas (`.exe`, `.bat`, `.cmd`, `.ps1`, `.sh`, `.dll`, etc.) para a pasta `inbound`.

---

## 6. Independência da IA (Hermes)

### Sintoma: Card Hermes exibe "Não configurado"
- **Comportamento Esperado:** O projeto Command v0.1.0 foi desenhado especificamente para ter **100% de independência de inteligência artificial** no controle e monitoramento direto do PC.
- O card do Hermes exibe "Não configurado" para indicar de forma transparente que nenhuma chave de IA ou serviço de terceiros está sendo utilizado ou é necessário para o funcionamento de todas as ferramentas de telemetria, captura, arquivos e ações do sistema.

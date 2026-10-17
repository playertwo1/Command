# YouTube

Manda mensagens no chat da sua live e mostra se o canal está ao vivo e quantas pessoas assistem, pela
YouTube Data API, com um cliente OAuth que você cria no Google Cloud.

## Configuração

1. No [console.cloud.google.com](https://console.cloud.google.com), crie um projeto e ative a
   **YouTube Data API v3**.
2. Em **Tela de permissão OAuth**, escolha **Externo** e adicione o seu e-mail como **usuário de
   teste** (o app fica em teste; não precisa publicar).
3. Em **Credenciais → Criar credenciais → ID do cliente OAuth**, escolha **App para computador**.
4. Copie o **Client ID** e o **Client Secret** para **Configuração → Integrações → YouTube** e toque
   em **Entrar com o Google**. O login abre no navegador do PC.

Num app para computador o Client Secret não é secreto de verdade (o Google sabe disso); mesmo assim, o
DroidDeck o guarda cifrado no PC.

## O que dá para fazer

| Operação | Detalhes |
|---|---|
| Mandar mensagem no chat | Vai para o chat da transmissão ao vivo ativa. |
| Só mostrar ao vivo/espectadores | Aceso ao vivo, com o número de espectadores. |

A transmissão é consultada a cada minuto, porque a cota diária da API é pequena.

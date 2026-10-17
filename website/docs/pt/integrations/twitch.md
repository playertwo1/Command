# Twitch

Ações do seu canal na Twitch (API Helix), com um app que você registra no console da Twitch. O login é
por código: o DroidDeck mostra um código e você confirma em `twitch.tv/activate`.

## Configuração

1. Entre em [dev.twitch.tv/console/apps](https://dev.twitch.tv/console/apps) e registre um aplicativo.
2. Em **URLs de redirecionamento OAuth**, use `http://localhost` (não é usado no login por código).
3. Em **Tipo de cliente**, escolha **Público**. Salve e copie o **Client ID**.
4. No DroidDeck, **Configuração → Integrações → Twitch**: cole o Client ID e toque em **Entrar com a
   Twitch**. A página de ativação abre no navegador do PC; confira o código e autorize.

## O que dá para fazer

| Operação | Detalhes |
|---|---|
| Criar marcador | Descrição opcional. Só funciona ao vivo. |
| Criar clipe | Do momento atual da live. |
| Rodar anúncio | 30 s a 3 min (conta de afiliado ou parceiro). |
| Mandar mensagem no chat | Como o seu usuário. |
| Abrir enquete | Pergunta, 2 a 5 opções (uma por linha) e duração (afiliado ou parceiro). |
| Trocar o título | O novo título da live. |
| Só mostrar ao vivo/espectadores | Aceso ao vivo, com o número de espectadores. |

Ao vivo e espectadores são atualizados a cada 30 segundos.

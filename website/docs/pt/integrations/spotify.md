# Spotify

Controla o Spotify da sua conta pela Web API, com um app que você cria no painel de desenvolvedor do
Spotify (gratuito). **Controlar a reprodução exige Spotify Premium.**

## Configuração

1. Entre em [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) e crie um app
   (**Create app**). Nome e descrição à vontade.
2. Em **Redirect URIs**, cadastre exatamente o endereço mostrado na tela do DroidDeck:
   `http://127.0.0.1:4787/api/integrations/spotify/callback`.
3. Marque **Web API**, salve e copie o **Client ID**.
4. No DroidDeck, **Configuração → Integrações → Spotify**: cole o Client ID e toque em **Entrar com o
   Spotify**. O login abre no navegador do PC (mesmo se você tocou no celular); autorize e pronto.

Não há segredo para guardar: o DroidDeck usa o fluxo PKCE. O token fica cifrado no PC.

## O que dá para fazer

| Operação | Botão |
|---|---|
| Tocar/pausar | ▶ / ⏸ |
| Próxima / Anterior | — |
| Curtir/descurtir a faixa | ♥ aceso quando a faixa está curtida |
| Aleatório | Aceso ligado |
| Repetir (desligado → playlist → faixa) | Aceso ligado; ícone de "repetir uma" na faixa |
| Volume (+/-) | Mostra o volume atual |
| Tocar uma playlist | Lista das suas playlists; opção de começar no aleatório |
| Mostrar o que está tocando | Capa, faixa e artista (o toque pausa/toca) |

- O estado é consultado a cada 3 segundos enquanto há celular conectado e botão de Spotify no deck.
- Os comandos vão para o aparelho ativo no Spotify (PC, celular, caixa...). Sem nenhum tocando, o
  Spotify responde que não há aparelho ativo: dê play nele uma vez.

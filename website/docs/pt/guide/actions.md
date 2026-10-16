# Botões e ações

Cada botão executa uma **ação**. Escolha o tipo de ação no painel de propriedades; os campos abaixo
dele mudam de acordo com o tipo.

!!! info "Atalho de teclado, Abrir app e Requisição HTTP são criados no PC"
    Por segurança, botões que enviam teclas, abrem programas ou fazem requisições HTTP (inclusive
    multi-ações com esses passos) só podem ser criados ou alterados no
    [configurador](../getting-started/configurator.md), no PC. O celular executa esses botões normalmente.

| Tipo de ação | Roda no | Resumo |
|---|---|---|
| [Atalho de teclado](#hotkey) | PC | Envia uma combinação de teclas para a janela em foco. |
| [Abrir app](#launch-app) | PC | Abre um programa, arquivo, pasta ou URL. |
| [Mídia](#media) | PC | Tocar/pausar, próxima, anterior, parar. |
| [Mixer](#mixer) | PC | Silencia apps; silencia ou ajusta o volume de dispositivos de áudio. |
| [Abrir perfil](#open-profile-and-back) | Celular | Abre outro perfil como uma pasta. |
| [Voltar](#open-profile-and-back) | Celular | Sai de uma pasta. |
| [Multiação](#multi-action) | PC | Executa vários passos em sequência, com esperas. |
| [Discord](../integrations/discord.md) | PC | Controles de voz e soundboard. |
| [OBS](../integrations/obs.md) | PC | Cenas, gravação, transmissão e mais. |
| [Soundboard](../integrations/soundboard.md) | PC | Toca um som. |
| [Tuya](../integrations/tuya.md) | PC | Controla dispositivos de casa inteligente. |
| [Home Assistant](../integrations/homeassistant.md) | PC | Luzes, tomadas, cenas, scripts e sensores. |
| [Spotify](../integrations/spotify.md) | PC | Player, curtir, aleatório, playlists e a capa no botão. |
| [Twitch](../integrations/twitch.md) | PC | Marcador, clipe, anúncio, chat, enquete e título. |
| [YouTube](../integrations/youtube.md) | PC | Chat da live e espectadores. |
| [Timer, pomodoro e contador](#timer) | PC | Relógio ao vivo no botão. |
| [Windows](#windows) | PC | Troca o áudio padrão, trava, suspende ou desliga a tela. |
| [Requisição HTTP](#http) | PC | Chama um webhook ou qualquer API. |
| [Jogo da Steam](#steam) | PC | Abre um jogo instalado, com a capa no botão. |

Cada botão também pode ter uma ação de [toque longo e de toque duplo](#gestures), ser um
[botão de dois estados](#two-states) e [mostrar uma informação](monitors.md) (relógio, clima, o que
está tocando...).

## Atalho de teclado { #hotkey }

Envia teclas para **a janela que está em foco** no PC.

O campo **Keys** usa a sintaxe *SendKeys* do Windows, mais `#` para a tecla Windows:

| Símbolo | Tecla | Exemplo |
|---|---|---|
| `^` | Ctrl | `^c` → Ctrl+C |
| `+` | Shift | `^+s` → Ctrl+Shift+S |
| `%` | Alt | `%{F4}` → Alt+F4 |
| `#` | Windows | `#d` → mostrar a área de trabalho, `#+s` → ferramenta de captura |
| `( )` | Segura os modificadores num grupo | `+(abc)` → ABC |
| `~` | Enter | `^a~` |
| `{NOME}` | Tecla especial | `{ENTER}`, `{TAB}`, `{ESC}`, `{SPACE}`, `{F1}`…`{F24}`, `{UP}`, `{DOWN}`, `{LEFT}`, `{RIGHT}`, `{HOME}`, `{END}`, `{PGUP}`, `{PGDN}`, `{INS}`, `{DEL}`, `{BS}`, `{PRTSC}`, `{NUMPAD0}`…`{NUMPAD9}`, `{VOLUME_UP}`, `{VOLUME_DOWN}`, `{VOLUME_MUTE}`, `{MEDIA_PLAY_PAUSE}`, `{MEDIA_NEXT}`, `{MEDIA_PREV}` |
| `{NOME n}` | Repetir | `{TAB 3}` |
| `{x}` | O próprio caractere | `{+}`, `{^}`, `{%}`, `{#}`, `{~}`, `{(}`, `{{}` |

Qualquer outro caractere é digitado como está. Com Ctrl, Alt ou Windows, letras ignoram maiúsculas:
`^C` é Ctrl+C; use `+` para o Shift.

As teclas saem com o scancode do teclado e ficam apertadas por um instante, então a maioria dos
jogos que leem o teclado diretamente também as recebe.

!!! warning "Limitações"
    - O Windows bloqueia entradas para apps rodando **como administrador**, a menos que o DroidDeck também rode como administrador.
    - Jogos com anti-cheat podem ignorar teclas simuladas.
    - Algumas combinações são reservadas pelo Windows e não podem ser simuladas, como Ctrl+Alt+Del e Win+L.

## Abrir app { #launch-app }

O caminho aceita qualquer coisa que você abriria pelo *Executar* (++win+r++): um `.exe`
(`C:\Windows\System32\notepad.exe`), um documento, uma pasta ou uma URL (`https://…`, `steam://…`).

## Mídia { #media }

Controla a sessão de mídia que o Windows mostra no overlay de mídia — Spotify, navegadores, players.

**Comando de mídia:** **Play / Pause** (padrão), **Próxima faixa**, **Faixa anterior**, **Parar**.
Um botão de tocar/pausar troca o ícone ao vivo entre ▶ e ⏸.

## Mixer { #mixer }

| Operação | Alvo: app | Alvo: dispositivo |
|---|---|---|
| Alternar mudo / Mutar / Desmutar | ✓ | ✓ |
| Definir volume (0–100) | — | ✓ |
| Volume + / Volume − (passo) | — | ✓ |

- **Aplicativo (processo)**: o nome do processo **sem** `.exe`, por exemplo `Spotify` ou `chrome`.
  Afeta todos os fluxos de áudio desse app. O volume por app fica na aba **Áudio** do celular.
- **Dispositivo do Windows**: **Padrão do Windows** segue o dispositivo padrão atual do Windows
  (escolha **saída** ou **entrada**, ou seja, alto-falante ou microfone), ou escolha um dispositivo
  específico. Aumentar o volume também tira o dispositivo do mudo.

Defina uma **cor ativa** para o botão acender enquanto o alvo estiver silenciado.

## Abrir perfil e voltar { #open-profile-and-back }

**Abrir perfil** mostra outro perfil por cima do atual, como uma pasta. Dá para aninhar pastas.
**Voltar** fecha a pasta atual; a seta da barra de título faz o mesmo. As duas ações rodam só no celular.

## Multiação { #multi-action }

Executa vários passos, um depois do outro. Cada passo tem uma **espera** (ms) que acontece **antes**
de ele rodar (**Esperar antes (ms)**). O editor oferece três tipos de passo:

- **Hotkey** — teclas, como acima;
- **Abrir app** — caminho, como acima;
- **Mutar app** — alterna o mudo de um processo.

Exemplo — "Iniciar reunião": abrir o app de reunião, esperar 3000 ms, enviar `^+m`.

### Gravar do teclado { #record }

No configurador do PC, **Gravar do teclado** grava o que você digitar no teclado do PC e transforma
em passos de atalho: vá até o programa, digite a sequência e clique em **Parar**.

- Teclas digitadas em sequência viram um passo só (`oi{ENTER}`); uma pausa de mais de meio segundo
  começa um passo novo, com a espera arredondada para 100 ms.
- A gravação para sozinha depois de 60 segundos.
- Por ler o teclado inteiro, só funciona no configurador aberto no próprio PC; o celular não tem esse
  botão. Revise os passos antes de salvar: tudo o que foi digitado entra, inclusive senhas.

## Timer, pomodoro e contador { #timer }

O botão mostra o tempo ao vivo. O relógio fica no PC, então todos os celulares veem o mesmo tempo e
o fim da contagem é detectado mesmo com a tela do celular apagada.

| Tipo | Toque | No fim |
|---|---|---|
| **Timer** | Inicia / pausa. Depois do fim, o toque zera. | Aviso sonoro no PC, vibração no celular e o botão acende na cor ativa. |
| **Cronômetro** | Inicia / pausa. | — |
| **Pomodoro** | Inicia / pausa. Foco e pausa se alternam sozinhos e o botão conta os ciclos. | Aviso a cada troca de fase. |
| **Contador** | Soma o **passo**. | — |

**Ao tocar** muda o que o toque faz: **Zerar**, **Pular para a próxima fase** (pomodoro), **Somar**
ou **Subtrair** (contador). Com **Timer controlado** um botão age sobre o timer de outro: por
exemplo, um botão "Zerar" ao lado do relógio. Os contadores continuam valendo depois de reiniciar o PC.

## Windows { #windows }

| Ação | O que faz |
|---|---|
| **Trocar o dispositivo de áudio padrão** | Define a saída (ou entrada) padrão do Windows. Com **Alternar com** preenchido, cada toque alterna entre os dois, por exemplo fone ↔ caixa de som. O botão acende enquanto o dispositivo escolhido é o padrão. |
| **Travar o computador** | Mesmo que ++win+l++. |
| **Suspender** | Põe o PC para dormir. |
| **Desligar a tela** | Desliga os monitores; mexer o mouse liga de novo. |

## Requisição HTTP { #http }

Chama uma URL a partir do PC: webhooks do n8n, do Home Assistant ou do IFTTT, ou qualquer API.
Escolha o **método**, a **URL**, os **cabeçalhos** (um por linha, `Nome: valor`) e, em POST/PUT/PATCH,
o **corpo** e o formato dele (JSON, formulário ou texto). A requisição tem 10 segundos para
responder, e o resultado fica no log do DroidDeck.

## Jogo da Steam { #steam }

Lista os jogos instalados na Steam do PC (todas as bibliotecas). Ao escolher um, o botão ganha o nome
e a capa do jogo; tocar abre o jogo pela Steam. A capa vem do cache da Steam: se um jogo aparecer sem
imagem, abra a biblioteca da Steam uma vez para ela baixar as capas.

## Toque longo e toque duplo { #gestures }

Além do toque normal, um botão pode ter uma ação para **segurar** e outra para **dois toques**
(seção *Toque longo e toque duplo* do editor). Os tipos de ação são os mesmos do toque normal.

- Exemplo: um timer que inicia no toque e zera no toque longo; uma cena do OBS no toque e a
  gravação no toque duplo.
- Só os botões com toque duplo esperam um instante (~0,3 s) antes de executar o toque simples, para
  diferenciar os dois. Os demais respondem na hora.
- Num botão com toque longo, segurar executa a ação; para editar o botão no celular, use o
  [modo de edição](profiles.md#modo-de-edicao).

## Dois estados { #two-states }

Na seção **Dois estados** do editor:

- **Alternar a cada toque** deixa o botão ligado num toque e desligado no seguinte, para ações sem
  estado próprio (um atalho que liga e desliga algo num jogo, por exemplo). O estado fica no PC: todos
  os celulares mostram o mesmo e ele continua depois de reiniciar.
- **Ação quando ligado** (opcional) roda no toque que desliga o botão. Exemplo: o toque liga a gravação
  por um atalho e o seguinte manda o atalho de parar. Sem ela, o mesmo toque roda sempre.
- **Rótulo quando ativo** e **Ícone quando ativo** trocam o visual quando o botão está ativo — pelo
  alternar ou pelo estado da própria ação (mudo do Discord, gravação do OBS, lâmpada acesa...).
  A **cor quando ativo** fica junto das cores do botão.

## Estado do botão

Alguns botões refletem o estado ao vivo:

| Ação | Estado exibido |
|---|---|
| Mídia tocar/pausar | Ícone ▶ / ⏸ |
| Mixer (mudo de app) | Ícone de volume e cor ativa enquanto silenciado |
| Discord | Cor ativa enquanto você está silenciado/ensurdecido |
| OBS | Aceso na cena atual, ou enquanto gravação/transmissão/câmera virtual/replay buffer estiver ligado |
| Tuya | Liga/desliga, nível de brilho e a cor real da lâmpada |
| Timer | Tempo restante ou decorrido, fase do pomodoro e cor ativa no fim |
| Windows (áudio) | Cor ativa enquanto o dispositivo é o padrão |
| Home Assistant | Aceso com a entidade ligada (com o brilho e a cor da luz), ou o valor do sensor |
| Spotify | Play/pause, curtida, aleatório e repetir; a capa no "mostrar o que está tocando" |
| Twitch / YouTube | Ao vivo e espectadores, no "só mostrar" |
| Dois estados | Cor, rótulo e ícone do ativo enquanto ligado |

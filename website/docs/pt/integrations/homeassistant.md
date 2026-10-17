# Home Assistant

O DroidDeck conecta no [Home Assistant](https://www.home-assistant.io) pela API WebSocket, com um token
de acesso: os botões mostram o estado real e mudam na hora, mesmo quando algo muda pelo próprio Home
Assistant.

## Configuração

1. No Home Assistant, abra o seu **perfil** (canto inferior esquerdo) → aba **Segurança**.
2. Em **Tokens de acesso de longa duração**, crie um token (por exemplo, `DroidDeck`) e copie — ele só
   aparece uma vez.
3. No DroidDeck, abra **Configuração → Integrações → Home Assistant** (no configurador, **Integrações**
   na barra lateral), preencha o **Endereço** (`http://homeassistant.local:8123` ou o IP) e o token, e
   toque em **Conectar**.

O token fica cifrado no PC. O PC precisa alcançar o Home Assistant na rede.

## O que dá para fazer

| Operação | Entidades | Botão |
|---|---|---|
| Liga/desliga | luz, tomada, ventilador, cortina, fechadura, media player, automação... | Aceso com a entidade ligada; luz mostra o brilho |
| Ligar / Desligar | as mesmas | idem |
| Brilho (+/-) | luzes | Passo de -100 a 100 % |
| Ativar cena | `scene.*` | — |
| Rodar script | `script.*` | — |
| Só mostrar o estado | sensores, clima, pessoas, `input_number`... | O valor com a unidade (`23.5 °C`) |
| Chamar um serviço | qualquer | `domínio.serviço` e dados em JSON |

- A lista de entidades vem do Home Assistant e é filtrada pela operação; dá para digitar um id que não
  esteja nela.
- Com cor (RGB), a luz pinta o botão com a cor real.
- Se a conexão cai, o PC tenta de novo sozinho (até a cada minuto).

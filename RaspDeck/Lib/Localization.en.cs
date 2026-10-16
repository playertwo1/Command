using System;
using System.Collections.Generic;

namespace DroidDeck.Lib
{
    /// <summary>
    /// Traducoes para ingles, chave = texto exato em portugues usado no codigo. Mudou o texto
    /// em portugues, mude a chave aqui tambem (senao volta a aparecer em portugues).
    /// </summary>
    public static partial class L
    {
        private static readonly Dictionary<string, string> En = new(StringComparer.Ordinal)
        {
            // ---- Categorias ----
            ["Sistema"] = "System",
            ["Mídia"] = "Media",
            ["Streaming"] = "Streaming",
            ["Casa"] = "Home",
            ["Utilidades"] = "Utilities",
            ["Navegação"] = "Navigation",

            // ---- Atalho, programa, janela ----
            ["Atalho de teclado"] = "Keyboard shortcut",
            ["Teclas"] = "Keys",
            ["^ = Ctrl, + = Shift, % = Alt, # = Win, {ENTER}, {F5}…"] = "^ = Ctrl, + = Shift, % = Alt, # = Win, {ENTER}, {F5}…",
            ["Abrir programa"] = "Open program",
            ["Abre um programa, arquivo ou endereço no PC."] = "Opens a program, file or address on the PC.",
            ["Caminho"] = "Path",
            ["Também aceita um arquivo ou uma URL."] = "Also accepts a file or a URL.",
            ["Argumentos (opcional)"] = "Arguments (optional)",
            ["Ativar janela"] = "Activate window",
            ["Título exato da janela"] = "Exact window title",

            // ---- Midia e mixer ----
            ["Comando"] = "Command",
            ["Play / Pause"] = "Play / Pause",
            ["Próxima faixa"] = "Next track",
            ["Faixa anterior"] = "Previous track",
            ["Parar"] = "Stop",
            ["Volume e mudo"] = "Volume and mute",

            // ---- Multi-acao, perfis ----
            ["Multi-ação"] = "Multi-action",
            ["Vários passos em sequência, com espera entre eles."] = "Several steps in sequence, with a wait between them.",
            ["Abrir perfil"] = "Open profile",
            ["Abre outro perfil como uma pasta."] = "Opens another profile like a folder.",
            ["Voltar"] = "Back",
            ["Volta ao perfil anterior."] = "Goes back to the previous profile.",

            // ---- OBS ----
            ["Ação do OBS"] = "OBS action",
            ["Trocar de cena"] = "Switch scene",
            ["Gravar (alternar)"] = "Record (toggle)",
            ["Transmitir / Live (alternar)"] = "Stream / Go live (toggle)",
            ["Câmera virtual (alternar)"] = "Virtual camera (toggle)",
            ["Replay buffer (alternar)"] = "Replay buffer (toggle)",
            ["Salvar replay"] = "Save replay",
            ["Mutar fonte de áudio (alternar)"] = "Mute audio source (toggle)",
            ["Mostrar / ocultar fonte"] = "Show / hide source",
            ["Ligar / desligar filtro"] = "Enable / disable filter",
            ["Pausar gravação (alternar)"] = "Pause recording (toggle)",
            ["Marcador de capítulo na gravação"] = "Chapter marker in recording",
            ["Captura de tela da cena"] = "Scene screenshot",
            ["Cena"] = "Scene",
            ["Fonte"] = "Source",
            ["Fonte ou cena do filtro"] = "Source or scene with the filter",
            ["Filtro"] = "Filter",
            ["Nome do capítulo (opcional)"] = "Chapter name (optional)",
            ["Exige OBS 30.2 ou mais novo, gravando em MP4 híbrido."] = "Requires OBS 30.2 or newer, recording to hybrid MP4.",
            ["Fonte de áudio"] = "Audio source",

            // ---- Tuya ----
            ["Casa inteligente (Tuya)"] = "Smart home (Tuya)",

            // ---- Windows ----
            ["Ação"] = "Action",
            ["Trocar o dispositivo de áudio padrão"] = "Change the default audio device",
            ["Travar o computador"] = "Lock the computer",
            ["Suspender"] = "Sleep",
            ["Desligar a tela"] = "Turn off the display",
            ["Tipo"] = "Type",
            ["Saída (fone, caixa de som)"] = "Output (headphones, speakers)",
            ["Entrada (microfone)"] = "Input (microphone)",
            ["Dispositivo"] = "Device",
            ["Alternar com (opcional)"] = "Toggle with (optional)",
            ["Com um segundo dispositivo, cada toque alterna entre os dois (fone ↔ caixa de som)."] =
                "With a second device, each tap switches between the two (headphones ↔ speakers).",
            ["Nenhum (só define o de cima)"] = "None (only sets the one above)",

            // ---- HTTP ----
            ["Requisição HTTP (webhook)"] = "HTTP request (webhook)",
            ["Chama uma URL a partir do PC: webhooks do n8n, Home Assistant, IFTTT ou qualquer API."] =
                "Calls a URL from the PC: n8n, Home Assistant or IFTTT webhooks, or any API.",
            ["Método"] = "Method",
            ["https://exemplo.com/webhook"] = "https://example.com/webhook",
            ["Cabeçalhos (opcional)"] = "Headers (optional)",
            ["Um por linha, no formato Nome: valor."] = "One per line, as Name: value.",
            ["Formato do corpo"] = "Body format",
            ["Formulário"] = "Form",
            ["Texto"] = "Text",
            ["Corpo (opcional)"] = "Body (optional)",
            ["{\"evento\": \"deck\"}"] = "{\"event\": \"deck\"}",

            // ---- Timer ----
            ["Timer, pomodoro e contador"] = "Timer, pomodoro and counter",
            ["O botão mostra o tempo ao vivo. Quando uma contagem termina, o PC toca um aviso e o celular vibra."] =
                "The button shows the time live. When a countdown ends, the PC plays an alert and the phone vibrates.",
            ["Timer (contagem regressiva)"] = "Timer (countdown)",
            ["Cronômetro"] = "Stopwatch",
            ["Pomodoro (foco e pausa)"] = "Pomodoro (focus and break)",
            ["Contador"] = "Counter",
            ["Duração"] = "Duration",
            ["Foco"] = "Focus",
            ["Pausa"] = "Break",
            ["Ao tocar"] = "On tap",
            ["Iniciar / pausar (contador: somar)"] = "Start / pause (counter: add)",
            ["Zerar"] = "Reset",
            ["Pular para a próxima fase (pomodoro)"] = "Skip to the next phase (pomodoro)",
            ["Somar (contador)"] = "Add (counter)",
            ["Subtrair (contador)"] = "Subtract (counter)",
            ["Passo"] = "Step",
            ["Timer controlado"] = "Controlled timer",
            ["Para um botão de \"zerar\" separado, escolha o timer de outro botão."] =
                "For a separate \"reset\" button, pick another button's timer.",
            ["Este botão"] = "This button",

            // ---- Steam ----
            ["Jogo da Steam"] = "Steam game",
            ["Jogo"] = "Game",

            // ---- Home Assistant ----
            ["Luzes, tomadas, cenas, scripts e sensores do Home Assistant, com o estado real."] =
                "Home Assistant lights, plugs, scenes, scripts and sensors, with their real state.",
            ["O que fazer"] = "What to do",
            ["Liga/desliga"] = "Toggle on/off",
            ["Ligar"] = "Turn on",
            ["Desligar"] = "Turn off",
            ["Brilho (+/-)"] = "Brightness (+/-)",
            ["Ativar cena"] = "Activate scene",
            ["Rodar script"] = "Run script",
            ["Só mostrar o estado"] = "Only show the state",
            ["Chamar um serviço"] = "Call a service",
            ["Entidade"] = "Entity",
            ["Passo do brilho"] = "Brightness step",
            ["Serviço"] = "Service",
            ["domínio.serviço"] = "domain.service",
            ["Dados (JSON, opcional)"] = "Data (JSON, optional)",

            // ---- Spotify ----
            ["Controla o Spotify da sua conta (Premium), com capa, curtida e aleatório no botão."] =
                "Controls Spotify on your (Premium) account, with cover art, like and shuffle on the button.",
            ["Tocar/pausar"] = "Play/pause",
            ["Próxima"] = "Next",
            ["Anterior"] = "Previous",
            ["Curtir/descurtir a faixa"] = "Like/unlike the track",
            ["Aleatório liga/desliga"] = "Shuffle on/off",
            ["Repetir (desligado → playlist → faixa)"] = "Repeat (off → playlist → track)",
            ["Volume (+/-)"] = "Volume (+/-)",
            ["Tocar uma playlist"] = "Play a playlist",
            ["Mostrar o que está tocando"] = "Show what's playing",
            ["Passo do volume"] = "Volume step",
            ["Começar no aleatório"] = "Start shuffled",

            // ---- Twitch ----
            ["Marcador, clipe, anúncio, chat, enquete e título do seu canal; mostra se está ao vivo."] =
                "Marker, clip, ad, chat, poll and title for your channel; shows whether you're live.",
            ["Criar marcador"] = "Create marker",
            ["Criar clipe"] = "Create clip",
            ["Rodar anúncio"] = "Run ad",
            ["Mandar mensagem no chat"] = "Send chat message",
            ["Abrir enquete"] = "Start poll",
            ["Trocar o título"] = "Change the title",
            ["Só mostrar ao vivo/espectadores"] = "Only show live/viewers",
            ["Descrição (opcional)"] = "Description (optional)",
            ["Momento épico"] = "Epic moment",
            ["Mensagem"] = "Message",
            ["Sigam o canal!"] = "Follow the channel!",
            ["Pergunta"] = "Question",
            ["Qual jogo agora?"] = "Which game next?",
            ["Opções (uma por linha, 2 a 5)"] = "Options (one per line, 2 to 5)",
            ["Sim"] = "Yes",
            ["Não"] = "No",
            ["Novo título"] = "New title",

            // ---- YouTube ----
            ["Manda mensagens no chat da sua live e mostra se está ao vivo e quantos assistem."] =
                "Sends messages to your live chat and shows whether you're live and how many are watching.",
            ["Obrigado por assistir!"] = "Thanks for watching!",

            // ==== Mensagens de erro e de status que chegam ao app ====

            // Seguranca (acoes privilegiadas so no PC)
            ["Botões que abrem programas, enviam atalhos, ativam janelas ou fazem requisições HTTP só podem ser criados ou alterados no configurador do PC (http://localhost:4787)."] =
                "Buttons that open programs, send shortcuts, activate windows or make HTTP requests can only be created or changed in the PC configurator (http://localhost:4787).",
            [" Botão: \"{label}\"."] = " Button: \"{label}\".",
            ["Gravar macro só funciona no configurador do PC (http://localhost:4787)."] =
                "Macro recording only works in the PC configurator (http://localhost:4787).",
            ["O backup tem botões que abrem programas, enviam atalhos ou fazem requisições. Importe pelo configurador no PC (http://localhost:4787)."] =
                "The backup has buttons that open programs, send shortcuts or make requests. Import it from the PC configurator (http://localhost:4787).",

            // Backup
            ["Não é um backup do DroidDeck (o arquivo não é um .droiddeck válido)."] = "Not a DroidDeck backup (the file is not a valid .droiddeck).",
            ["Não é um backup do DroidDeck (falta o manifest.json)."] = "Not a DroidDeck backup (manifest.json is missing).",
            ["Não é um backup do DroidDeck."] = "Not a DroidDeck backup.",
            ["Backup de uma versão mais nova do DroidDeck. Atualize o DroidDeck no PC."] = "Backup from a newer DroidDeck version. Update DroidDeck on the PC.",
            ["Arquivo de backup corrompido."] = "Corrupted backup file.",

            // Integracoes com conta
            ["Integração desconhecida."] = "Unknown integration.",
            ["Esta integração não usa login pelo navegador."] = "This integration doesn't use browser login.",
            ["Entre na conta de novo."] = "Sign in again.",
            ["Login cancelado."] = "Login cancelled.",
            ["Este link de login expirou. Comece de novo pelo DroidDeck."] = "This login link has expired. Start again from DroidDeck.",
            ["Spotify conectado"] = "Spotify connected",
            ["YouTube conectado"] = "YouTube connected",
            ["Conta {account}. Pode fechar esta aba."] = "Account {account}. You can close this tab.",
            ["Canal {channel}. Pode fechar esta aba."] = "Channel {channel}. You can close this tab.",
            ["O Spotify recusou: {error}"] = "Spotify refused: {error}",
            ["O Google recusou: {error}"] = "Google refused: {error}",
            ["Não deu certo: {error}"] = "It didn't work: {error}",
            ["Endereço inválido. Ex.: http://homeassistant.local:8123"] = "Invalid address. E.g.: http://homeassistant.local:8123",
            ["Falta o token de acesso."] = "The access token is missing.",
            ["Não foi possível conectar ao Home Assistant. Confira o endereço."] = "Couldn't connect to Home Assistant. Check the address.",
            ["Resposta inesperada do Home Assistant."] = "Unexpected response from Home Assistant.",
            ["Token recusado pelo Home Assistant. Gere outro no seu perfil."] = "Home Assistant rejected the token. Create a new one in your profile.",
            ["O Home Assistant recusou."] = "Home Assistant refused.",
            ["Home Assistant desconectado."] = "Home Assistant disconnected.",
            ["O Home Assistant não respondeu."] = "Home Assistant didn't respond.",
            ["Serviço no formato domínio.serviço"] = "Service in domain.service format",
            ["Cole o Client ID do app que você criou no Spotify for Developers."] = "Paste the Client ID of the app you created in Spotify for Developers.",
            ["Nada tocando no Spotify."] = "Nothing playing on Spotify.",
            ["Escolha a playlist."] = "Choose the playlist.",
            ["Cole o Client ID do app que você criou no console da Twitch."] = "Paste the Client ID of the app you created in the Twitch console.",
            ["O código expirou. Tente de novo."] = "The code expired. Try again.",
            ["Sem token."] = "No token.",
            ["Twitch desconectada."] = "Twitch disconnected.",
            ["A enquete precisa de 2 opções."] = "The poll needs 2 options.",
            ["O Client ID termina em .apps.googleusercontent.com."] = "The Client ID ends in .apps.googleusercontent.com.",
            ["Falta o Client Secret."] = "The Client Secret is missing.",
            ["Esta conta Google não tem canal no YouTube."] = "This Google account has no YouTube channel.",
            ["Nenhuma transmissão ao vivo no canal."] = "No live stream on the channel.",

            // OBS, Discord, Tuya, Soundboard
            ["OBS não respondeu (handshake). O obs-websocket está ativo?"] = "OBS didn't respond (handshake). Is obs-websocket enabled?",
            ["OBS não está conectado."] = "OBS is not connected.",
            ["OBS recusou o pedido."] = "OBS refused the request.",
            ["Configure o Client ID e o Secret do Discord primeiro."] = "Set up the Discord Client ID and Secret first.",
            ["Discord não respondeu ao handshake (READY). Se continuar, feche o Discord pela bandeja (Sair do Discord) e abra de novo."] =
                "Discord didn't answer the handshake (READY). If it keeps happening, quit Discord from the tray (Quit Discord) and open it again.",
            ["A autorização do Discord expirou: abra Configurações → Discord e toque em Conectar."] =
                "The Discord authorization expired: open Settings → Discord and tap Connect.",
            ["Discord não está conectado."] = "Discord is not connected.",
            ["Pipe do Discord não encontrado — o Discord está aberto?"] = "Discord pipe not found — is Discord open?",
            ["Discord fechou a conexão (CLOSE)."] = "Discord closed the connection (CLOSE).",
            ["Pipe fechado."] = "Pipe closed.",
            ["clientId e clientSecret obrigatórios"] = "clientId and clientSecret are required",
            ["soundId é obrigatório"] = "soundId is required",
            ["QR expirado; gere outro."] = "QR code expired; generate a new one.",
            ["Tuya nao pareado."] = "Tuya is not paired.",
            ["Tuya nao conectado."] = "Tuya is not connected.",
            ["userCode obrigatorio"] = "userCode is required",
            ["deviceId e code obrigatorios"] = "deviceId and code are required",
            ["url é obrigatório"] = "url is required",
            ["URL de som invalida (so http/https)."] = "Invalid sound URL (http/https only).",
            ["Arquivo de som grande demais."] = "Sound file is too large.",
        };
    }
}

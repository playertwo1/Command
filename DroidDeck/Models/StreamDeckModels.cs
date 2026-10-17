using System.Collections.Generic;

namespace DroidDeck.Models
{
    public class DeckProfile
    {
        public string Id { get; set; } = System.Guid.NewGuid().ToString();
        public string Name { get; set; } = "New Profile";
        public int Rows { get; set; } = 3;
        public int Columns { get; set; } = 4;
        public bool IsDefault { get; set; } = false;
        public List<DeckButton> Buttons { get; set; } = new List<DeckButton>();

        /// <summary>
        /// Processos (sem .exe) que trazem este perfil para a frente quando a janela deles
        /// ganha o foco no PC. Vazio = sem troca automatica.
        /// </summary>
        public List<string>? AutoSwitchApps { get; set; }
    }

    public class DeckButton
    {
        public string Id { get; set; } = System.Guid.NewGuid().ToString();
        public int Row { get; set; }
        public int Column { get; set; }
        public string? Label { get; set; }
        public string? IconBase64 { get; set; }
        public string? IconName { get; set; } // Material icon name
        public string? BackgroundColor { get; set; }
        public string? ActiveColor { get; set; } // Cor quando o botão está "ativo" (toggle: mute/discord ligado)
        public string? DynamicType { get; set; }
        public DeckAction? Action { get; set; }

        /// <summary>Acao do toque longo. Sem ela, o toque longo abre o editor no celular.</summary>
        public DeckAction? LongPressAction { get; set; }

        /// <summary>Acao do toque duplo. Com ela, o toque simples espera um instante para diferenciar.</summary>
        public DeckAction? DoubleTapAction { get; set; }

        // ---- Dois estados ----

        /// <summary>
        /// Alterna entre desligado e ligado a cada toque, com o estado guardado no PC. Serve
        /// para acoes sem estado proprio (um atalho que liga/desliga algo num jogo, p.ex.).
        /// </summary>
        public bool Toggle { get; set; }

        /// <summary>Com Toggle: acao do toque quando o botao esta ligado. Null = a mesma do toque.</summary>
        public DeckAction? ActiveAction { get; set; }

        /// <summary>Rotulo e icone quando o botao esta ativo (pelo Toggle ou pelo estado da acao).</summary>
        public string? ActiveLabel { get; set; }
        public string? ActiveIconName { get; set; }
        public string? ActiveIconBase64 { get; set; }

        /// <summary>Parametros do botao de informacao (cidade do clima, comando, URL...).</summary>
        public Dictionary<string, string>? DynamicParameters { get; set; }

        /// <summary>Acao de um gesto: "tap" (padrao), "longPress", "doubleTap" ou "active" (Toggle ligado).</summary>
        public DeckAction? ActionFor(string? gesture) => (gesture ?? "").ToLowerInvariant() switch
        {
            "longpress" => LongPressAction,
            "doubletap" => DoubleTapAction,
            "active" => ActiveAction,
            _ => Action,
        };

        public static readonly string[] Gestures = { "tap", "longPress", "doubleTap" };

        /// <summary>Todas as acoes guardadas no botao (gestos e a do estado ligado).</summary>
        public static readonly string[] ActionSlots = { "tap", "longPress", "doubleTap", "active" };
    }

    public class DeckAction
    {
        public string Type { get; set; } = "none"; // launchApp, media, mixer, hotkey, etc
        public Dictionary<string, string> Parameters { get; set; } = new Dictionary<string, string>();
    }

    /// <summary>Um passo de multi-ação: parameters["steps"] guarda uma lista destes em JSON.</summary>
    public class MultiStep
    {
        public string? Type { get; set; }
        public Dictionary<string, string>? Parameters { get; set; }
        public int DelayMs { get; set; }
    }

    /// <summary>
    /// Grade física do deck. Definida pelo celular (quantos botões cabem inteiros na tela)
    /// e enviada ao PC; o configurador web usa estes valores (não há seletor manual).
    /// É global (todos os perfis compartilham a mesma grade).
    /// </summary>
    public class DeviceLayout
    {
        public int Rows { get; set; } = 3;
        public int Columns { get; set; } = 5;
    }
}

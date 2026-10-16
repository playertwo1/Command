using System.Collections.Generic;
using System.Threading.Tasks;
using DroidDeck.Services;

namespace DroidDeck.Actions.Providers
{
    /// <summary>Abre um programa, arquivo ou URL. Privilegiada: so nasce no configurador.</summary>
    public class LaunchAppProvider : IActionProvider
    {
        private readonly IAppActivator _activator;

        public LaunchAppProvider(IAppActivator activator) => _activator = activator;

        public string Type => "launch_app";
        public IReadOnlyCollection<string> Aliases => new[] { "launchapp" };

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Abrir programa",
            Icon = "launch",
            Category = "Sistema",
            Description = "Abre um programa, arquivo ou endereço no PC.",
            Fields =
            {
                ActionField.Text("path", "Caminho", @"C:\Windows\System32\notepad.exe",
                    "Também aceita um arquivo ou uma URL.", required: true),
                ActionField.Text("arguments", "Argumentos (opcional)"),
            },
        };

        public Task ExecuteAsync(ActionContext c)
        {
            var path = c.Get("path");
            if (path.Length > 0) _activator.LaunchApp(path, c.Get("arguments"));
            return Task.CompletedTask;
        }
    }

    /// <summary>Traz uma janela para a frente pelo titulo. Privilegiada.</summary>
    public class ActivateWindowProvider : IActionProvider
    {
        private readonly IAppActivator _activator;

        public ActivateWindowProvider(IAppActivator activator) => _activator = activator;

        public string Type => "activatewindow";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Ativar janela",
            Icon = "web_asset",
            Category = "Sistema",
            Fields = { ActionField.Text("windowName", "Título exato da janela", required: true) },
        };

        public Task ExecuteAsync(ActionContext c)
        {
            _activator.ActivateWindow(c.Get("windowName"));
            return Task.CompletedTask;
        }
    }

    /// <summary>Atalho de teclado via SendInput. Privilegiada.</summary>
    public class HotkeyProvider : IActionProvider
    {
        private readonly IAppActivator _activator;

        public HotkeyProvider(IAppActivator activator) => _activator = activator;

        public string Type => "hotkey";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Atalho de teclado",
            Icon = "keyboard",
            Category = "Sistema",
            Fields =
            {
                ActionField.Text("keys", "Teclas", "^C", "^ = Ctrl, + = Shift, % = Alt, # = Win, {ENTER}, {F5}…", required: true),
            },
        };

        public Task ExecuteAsync(ActionContext c)
        {
            var keys = c.Get("keys");
            if (keys.Length > 0) _activator.SendKeys(keys);
            return Task.CompletedTask;
        }
    }

    /// <summary>
    /// Acoes que so o app executa (navegar entre perfis). Ficam no schema para aparecerem no
    /// seletor de tipo; se chegarem ao servidor, nao ha o que fazer.
    /// </summary>
    public class ClientOnlyProvider : IActionProvider
    {
        private readonly ActionSchema _schema;

        public ClientOnlyProvider(ActionSchema schema) => _schema = schema;

        public string Type => _schema.Type;
        public ActionSchema Describe() => _schema;
        public Task ExecuteAsync(ActionContext c) => Task.CompletedTask;

        public static IEnumerable<IActionProvider> All() => new IActionProvider[]
        {
            new ClientOnlyProvider(new ActionSchema
            {
                Type = "open_profile", Title = "Abrir perfil", Icon = "folder", Category = "Navegação",
                Description = "Abre outro perfil como uma pasta.", Editor = "open_profile",
            }),
            new ClientOnlyProvider(new ActionSchema
            {
                Type = "back", Title = "Voltar", Icon = "arrow_back", Category = "Navegação",
                Description = "Volta ao perfil anterior.",
            }),
        };
    }
}

using System;
using System.Diagnostics;
using System.Windows.Forms;
using Microsoft.Win32;

namespace DroidDeck
{
    /// <summary>
    /// Janela invisível que serve apenas de host para o ícone de bandeja (NotifyIcon).
    /// O DroidDeck roda como app de bandeja: o servidor web sobe em paralelo (ver Program.cs)
    /// e o usuário interage pelo menu do ícone. Não há janela visível.
    /// </summary>
    public partial class frmPrincipal : Form
    {
        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppRunName = "DroidDeck";
        private const string WebUrl = "http://localhost:4787/";

        private ToolStripMenuItem _autoStartItem = null!;
        private ToolStripMenuItem _firewallItem = null!;
        private ToolStripMenuItem _updateItem = null!;

        public frmPrincipal()
        {
            InitializeComponent();

            // Nunca aparece na barra de tarefas nem como janela; só o ícone de bandeja.
            ShowInTaskbar = false;
            BuildTrayMenu();
            ntiTray.Visible = true;
        }

        // A janela nunca é exibida, mas o handle precisa existir para o message loop
        // (e o ícone de bandeja) continuarem vivos. Sem CreateHandle, o Application.Run
        // encerraria de imediato por não haver janela principal realizada.
        protected override void SetVisibleCore(bool value)
        {
            if (!IsHandleCreated) CreateHandle();
            base.SetVisibleCore(false);
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            ntiTray.ShowBalloonTip(3000, "DroidDeck", "Rodando na bandeja — servidor em " + WebUrl, ToolTipIcon.Info);

            if (Program.FirstRunAfterInstall)
                BeginInvoke(FirstRunSetup);

            Program.Updater.UpdateReady += version => BeginInvoke(() => OnUpdateReady(version));
            Program.Updater.StartBackgroundChecks(_updateCts.Token);
        }

        private readonly System.Threading.CancellationTokenSource _updateCts = new();

        /// <summary>
        /// Logo depois de instalar: liga o "Iniciar com o Windows" (o deck precisa do PC
        /// ligado e o usuario quase sempre quer isso) e oferece liberar o firewall.
        /// </summary>
        private void FirstRunSetup()
        {
            SetAutoStart(true);
            _autoStartItem.Checked = true;

            if (Lib.FirewallSetup.RulesExist()) return;
            var answer = MessageBox.Show(
                "Para o celular encontrar e conectar no DroidDeck, o Firewall do Windows precisa " +
                $"liberar as portas {Lib.PairingInfo.Port} (TCP) e {Lib.FirewallSetup.DiscoveryPort} (UDP), " +
                "só para a sua rede local.\n\nLiberar agora? O Windows vai pedir permissão de administrador.",
                "DroidDeck", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (answer == DialogResult.Yes) AllowFirewall();
        }

        private void AllowFirewall()
        {
            if (Lib.FirewallSetup.AddRules())
                ntiTray.ShowBalloonTip(3000, "DroidDeck", "Firewall liberado para a rede local.", ToolTipIcon.Info);
            else
                ntiTray.ShowBalloonTip(5000, "DroidDeck",
                    "O firewall não foi alterado. Você pode tentar de novo pelo menu da bandeja.", ToolTipIcon.Warning);
            _firewallItem.Checked = Lib.FirewallSetup.RulesExist();
        }

        private void OnUpdateReady(string version)
        {
            _updateItem.Text = $"Reiniciar para atualizar (v{version})";
            ntiTray.ShowBalloonTip(5000, "DroidDeck",
                $"A versão {version} foi baixada e entra na próxima vez que o DroidDeck abrir. " +
                "Para atualizar agora, use o menu da bandeja.", ToolTipIcon.Info);
        }

        private async void OnUpdateClick()
        {
            var updater = Program.Updater;
            if (!updater.IsInstalled)
            {
                OpenUrl(Lib.AppUpdater.RepoUrl + "/releases/latest");
                return;
            }
            if (updater.PendingVersion != null)
            {
                updater.ApplyAndRestart();
                return;
            }

            _updateItem.Enabled = false;
            _updateItem.Text = "Procurando atualização…";
            var version = await updater.CheckAndDownloadAsync();
            _updateItem.Enabled = true;
            if (version == null)
            {
                _updateItem.Text = "Procurar atualização";
                ntiTray.ShowBalloonTip(3000, "DroidDeck",
                    $"Você está na versão mais recente ({updater.CurrentVersion}).", ToolTipIcon.Info);
            }
        }

        private void BuildTrayMenu()
        {
            var menu = new ContextMenuStrip();

            var openItem = new ToolStripMenuItem("Abrir no navegador");
            openItem.Click += (_, _) => OpenWebUi();

            var pairItem = new ToolStripMenuItem("Parear dispositivo (QR)…");
            pairItem.Click += (_, _) =>
            {
                using var f = new frmPairing();
                f.ShowDialog();
            };

            _autoStartItem = new ToolStripMenuItem("Iniciar com o Windows")
            {
                CheckOnClick = true,
                Checked = IsAutoStartEnabled(),
            };
            _autoStartItem.Click += (_, _) => SetAutoStart(_autoStartItem.Checked);

            _firewallItem = new ToolStripMenuItem("Liberar no firewall (rede local)")
            {
                Checked = Lib.FirewallSetup.RulesExist(),
            };
            _firewallItem.Click += (_, _) => AllowFirewall();

            // Copia instalada: procura e aplica atualizacoes. Zip/dev: abre a pagina da release.
            var version = Program.Updater.CurrentVersion;
            var versionItem = new ToolStripMenuItem(version != null ? $"DroidDeck v{version}" : "DroidDeck (sem instalador)")
            {
                Enabled = false,
            };
            _updateItem = new ToolStripMenuItem(Program.Updater.IsInstalled ? "Procurar atualização" : "Baixar versão mais recente…");
            _updateItem.Click += (_, _) => OnUpdateClick();

            var exitItem = new ToolStripMenuItem("Sair");
            exitItem.Click += (_, _) => Application.Exit();

            menu.Items.Add(openItem);
            menu.Items.Add(pairItem);
            menu.Items.Add(_autoStartItem);
            menu.Items.Add(_firewallItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(versionItem);
            menu.Items.Add(_updateItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(exitItem);

            ntiTray.ContextMenuStrip = menu;
            ntiTray.DoubleClick += (_, _) => OpenWebUi();
        }

        private static void OpenWebUi() => OpenUrl(WebUrl);

        private static void OpenUrl(string url)
        {
            try
            {
                Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                Lib.Log.Error($"Falha ao abrir a Web UI: {ex.Message}");
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            // Remove o ícone para não deixar "fantasma" na bandeja.
            ntiTray.Visible = false;
            _updateCts.Cancel();
            base.OnFormClosing(e);
        }

        private static bool IsAutoStartEnabled()
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, false);
            return key?.GetValue(AppRunName) != null;
        }

        internal static void SetAutoStart(bool enable)
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKey, true)
                    ?? Registry.CurrentUser.CreateSubKey(RunKey);
                if (key == null) return;

                if (enable)
                    key.SetValue(AppRunName, $"\"{Application.ExecutablePath}\"");
                else
                    key.DeleteValue(AppRunName, throwOnMissingValue: false);
            }
            catch (Exception ex)
            {
                Lib.Log.Error($"Falha ao configurar autostart: {ex.Message}");
            }
        }

        /// <summary>
        /// Desinstalacao: tira o autostart so se ele aponta para esta copia. Outra copia do
        /// DroidDeck (um .zip antigo, um build de dev) continua iniciando com o Windows.
        /// </summary>
        internal static void RemoveAutoStartIfOurs()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKey, true);
                var current = key?.GetValue(AppRunName) as string;
                if (current != null &&
                    current.Trim('"').Equals(Application.ExecutablePath, StringComparison.OrdinalIgnoreCase))
                    key!.DeleteValue(AppRunName, throwOnMissingValue: false);
            }
            catch (Exception ex)
            {
                Lib.Log.Error($"Falha ao remover autostart: {ex.Message}");
            }
        }
    }
}

using System;
using System.Diagnostics;
using System.Windows.Forms;
using Microsoft.Win32;
using DroidDeck.Lib;

namespace DroidDeck
{
    /// <summary>
    /// Janela invisível que serve apenas de host para o ícone de bandeja (NotifyIcon).
    /// O Command roda como app de bandeja: o servidor web sobe em paralelo (ver Program.cs)
    /// e o usuário interage pelo menu do ícone. Não há janela visível.
    /// </summary>
    public partial class frmPrincipal : Form
    {
        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppRunName = "Command";
        private const string WebUrl = "http://localhost:4787/";

        private ToolStripMenuItem _autoStartItem = null!;
        private ToolStripMenuItem _firewallItem = null!;
        private ToolStripMenuItem _updateItem = null!;
        private ToolStripMenuItem _endRemoteControlItem = null!;

        public frmPrincipal()
        {
            InitializeComponent();

            var appIcon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath)
                ?? System.Drawing.SystemIcons.Application;
            Icon = appIcon;
            ntiTray.Icon = appIcon;

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
            ntiTray.ShowBalloonTip(3000, "Command",
                L.Ui("Rodando na bandeja — servidor em {url}", ("url", WebUrl)), ToolTipIcon.Info);

            if (Program.FirstRunAfterInstall)
                BeginInvoke(FirstRunSetup);

            Program.Updater.UpdateReady += version => BeginInvoke(() => OnUpdateReady(version));
            Program.Updater.StartBackgroundChecks(_updateCts.Token);

            Services.RemoteControlSessionService.Shared.SessionChanged += session =>
            {
                if (IsDisposed || !IsHandleCreated) return;
                try
                {
                    BeginInvoke(() =>
                    {
                        if (session != null)
                        {
                            _endRemoteControlItem.Text = L.Ui("Encerrar controle remoto ({device})", ("device", session.DeviceId));
                            _endRemoteControlItem.Visible = true;
                            ntiTray.ShowBalloonTip(3000, "Command",
                                L.Ui("Controle remoto ativo pelo dispositivo {device}.", ("device", session.DeviceId)), ToolTipIcon.Info);
                        }
                        else
                        {
                            _endRemoteControlItem.Visible = false;
                        }
                    });
                }
                catch { }
            };
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

            PromptLegacyMigrationIfAvailable(showWhenNoData: false);

            if (Lib.FirewallSetup.RulesExist()) return;
            var answer = MessageBox.Show(
                L.Ui("Para o celular encontrar e conectar no Command, o Firewall do Windows precisa liberar as portas {tcp} (TCP) e {udp} (UDP), só para a sua rede local.\n\nLiberar agora? O Windows vai pedir permissão de administrador.",
                    ("tcp", Lib.PairingInfo.Port), ("udp", Lib.FirewallSetup.DiscoveryPort)),
                "Command", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (answer == DialogResult.Yes) AllowFirewall();
        }

        private void PromptLegacyMigrationIfAvailable(bool showWhenNoData)
        {
            try
            {
                var migrationService = new Services.LegacyDataMigrationService(
                    Microsoft.Extensions.Logging.Abstractions.NullLogger<Services.LegacyDataMigrationService>.Instance);
                var plan = migrationService.BuildPlan();
                if (!plan.HasLegacyData)
                {
                    if (showWhenNoData)
                    {
                        MessageBox.Show(
                            L.Ui("Nenhum dado ou perfil do DroidDeck legado foi encontrado neste computador."),
                            "Command - Migração de Dados", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    return;
                }

                var answer = MessageBox.Show(
                    L.Ui("Foram encontrados dados de perfis e configurações do DroidDeck legado no seu computador ({count} arquivo(s)).\n\nDeseja migrar esses dados com segurança para o Command?\n\nOs arquivos originais serão preservados intactos.", ("count", plan.Candidates.Count.ToString())),
                    "Command - Migração de Dados", MessageBoxButtons.YesNo, MessageBoxIcon.Question);

                if (answer == DialogResult.Yes)
                {
                    var result = migrationService.ExecuteMigrationAsync(explicitConsent: true).GetAwaiter().GetResult();
                    if (result.Success)
                    {
                        ntiTray.ShowBalloonTip(5000, "Command",
                            L.Ui("Migração concluída com sucesso ({migrated} arquivo(s) migrado(s)).", ("migrated", result.MigratedCount.ToString())),
                            ToolTipIcon.Info);
                    }
                    else
                    {
                        ntiTray.ShowBalloonTip(5000, "Command",
                            L.Ui("A migração teve {failed} falha(s). Os dados originais foram mantidos intactos.", ("failed", result.FailedCount.ToString())),
                            ToolTipIcon.Warning);
                    }
                }
            }
            catch (Exception ex)
            {
                Lib.Log.Warning($"Erro ao verificar dados legados para migração: {ex.Message}");
            }
        }

        private void AllowFirewall()
        {
            if (Lib.FirewallSetup.AddRules())
                ntiTray.ShowBalloonTip(3000, "Command", L.Ui("Firewall liberado para a rede local."), ToolTipIcon.Info);
            else
                ntiTray.ShowBalloonTip(5000, "Command",
                    L.Ui("O firewall não foi alterado. Você pode tentar de novo pelo menu da bandeja."), ToolTipIcon.Warning);
            _firewallItem.Checked = Lib.FirewallSetup.RulesExist();
        }

        private void OnUpdateReady(string version)
        {
            _updateItem.Text = L.Ui("Reiniciar para atualizar (v{version})", ("version", version));
            ntiTray.ShowBalloonTip(5000, "Command",
                L.Ui("A versão {version} foi baixada e entra na próxima vez que o Command abrir. Para atualizar agora, use o menu da bandeja.",
                    ("version", version)), ToolTipIcon.Info);
        }

        private async void OnUpdateClick()
        {
            var updater = Program.Updater;
            if (!updater.IsInstalled)
            {
                OpenUrl(Lib.AppUpdater.RepoUrl + "/releases/latest");
                return;
            }
            if (!updater.IsUpdateFeedConfigured)
            {
                ntiTray.ShowBalloonTip(5000, "Command",
                    L.Ui("Atualizações remotas estão desativadas neste instalador piloto."), ToolTipIcon.Info);
                return;
            }
            if (updater.PendingVersion != null)
            {
                updater.ApplyAndRestart();
                return;
            }

            _updateItem.Enabled = false;
            _updateItem.Text = L.Ui("Procurando atualização…");
            var version = await updater.CheckAndDownloadAsync();
            _updateItem.Enabled = true;
            if (version == null)
            {
                _updateItem.Text = L.Ui("Procurar atualização");
                ntiTray.ShowBalloonTip(3000, "Command",
                    L.Ui("Você está na versão mais recente ({version}).", ("version", updater.CurrentVersion)), ToolTipIcon.Info);
            }
        }

        private void BuildTrayMenu()
        {
            var menu = new ContextMenuStrip();

            var openItem = new ToolStripMenuItem(L.Ui("Abrir no navegador"));
            openItem.Click += (_, _) => OpenWebUi();

            var pairItem = new ToolStripMenuItem(L.Ui("Parear dispositivo (QR)…"));
            pairItem.Click += (_, _) =>
            {
                using var f = new frmPairing();
                f.ShowDialog();
            };

            var foldersItem = new ToolStripMenuItem(L.Ui("Pastas de destino…"));
            foldersItem.Click += (_, _) =>
            {
                using var f = new frmDestinations(Services.DestinationFolderStore.Shared);
                f.ShowDialog();
            };

            _endRemoteControlItem = new ToolStripMenuItem(L.Ui("Encerrar controle remoto"))
            {
                Visible = false,
            };
            _endRemoteControlItem.Click += (_, _) =>
            {
                Services.RemoteControlSessionService.Shared.ForceEndSession("TerminatedFromTray");
            };

            _autoStartItem = new ToolStripMenuItem(L.Ui("Iniciar com o Windows"))
            {
                CheckOnClick = true,
                Checked = IsAutoStartEnabled(),
            };
            _autoStartItem.Click += (_, _) => SetAutoStart(_autoStartItem.Checked);

            _firewallItem = new ToolStripMenuItem(L.Ui("Liberar no firewall (rede local)"))
            {
                Checked = Lib.FirewallSetup.RulesExist(),
            };
            _firewallItem.Click += (_, _) => AllowFirewall();

            var migrateItem = new ToolStripMenuItem(L.Ui("Migrar dados do DroidDeck…"));
            migrateItem.Click += (_, _) => PromptLegacyMigrationIfAvailable(showWhenNoData: true);

            // O piloto não consulta um feed privado. Builds de desenvolvimento abrem a página Command.
            var version = Program.Updater.CurrentVersion;
            var versionItem = new ToolStripMenuItem(version != null
                ? L.Ui("Command v{version}", ("version", version))
                : L.Ui("Command (sem instalador)"))
            {
                Enabled = false,
            };
            var hasUpdateFeed = Program.Updater.IsUpdateFeedConfigured;
            var isInstalled = Program.Updater.IsInstalled;
            _updateItem = new ToolStripMenuItem(isInstalled
                ? hasUpdateFeed ? L.Ui("Procurar atualização") : L.Ui("Atualizações desativadas neste piloto")
                : L.Ui("Ver releases do Command"))
            {
                Enabled = !isInstalled || hasUpdateFeed,
            };
            _updateItem.Click += (_, _) => OnUpdateClick();

            var exitItem = new ToolStripMenuItem(L.Ui("Sair"));
            exitItem.Click += (_, _) => Application.Exit();

            menu.Items.Add(openItem);
            menu.Items.Add(pairItem);
            menu.Items.Add(foldersItem);
            menu.Items.Add(_endRemoteControlItem);
            menu.Items.Add(_autoStartItem);
            menu.Items.Add(_firewallItem);
            menu.Items.Add(migrateItem);
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
        /// Outra copia do Command (um .zip ou build de dev) continua iniciando com o Windows.
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

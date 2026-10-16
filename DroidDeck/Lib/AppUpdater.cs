using System;
using System.Threading;
using System.Threading.Tasks;
using Velopack;
using Velopack.Sources;

namespace DroidDeck.Lib
{
    /// <summary>
    /// Atualizacao automatica pelas Releases do GitHub (Velopack).
    ///
    /// So age na copia instalada pelo DroidDeck-Setup.exe; o .zip e o "dotnet run" seguem
    /// como antes. A atualizacao e baixada em segundo plano e aplicada na proxima vez que o
    /// DroidDeck abrir (VelopackApp aplica pacotes pendentes no startup), ou na hora, se o
    /// usuario aceitar reiniciar.
    /// </summary>
    public class AppUpdater
    {
        public const string RepoUrl = "https://github.com/ggfto/DroidDeck";

        private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(6);

        private readonly UpdateManager _manager = new(new GithubSource(RepoUrl, null, false));
        private readonly SemaphoreSlim _lock = new(1, 1);
        private UpdateInfo? _ready;

        /// <summary>Versao baixada e pronta para aplicar.</summary>
        public event Action<string>? UpdateReady;

        public bool IsInstalled => _manager.IsInstalled;

        public string? CurrentVersion => _manager.CurrentVersion?.ToString();

        public string? PendingVersion => _ready?.TargetFullRelease.Version.ToString();

        /// <summary>Checa agora e depois a cada <see cref="CheckInterval"/>.</summary>
        public void StartBackgroundChecks(CancellationToken token)
        {
            if (!IsInstalled) return;
            _ = Task.Run(async () =>
            {
                // Deixa o servidor subir primeiro; atualizar nao tem pressa.
                try { await Task.Delay(TimeSpan.FromSeconds(30), token); } catch { return; }
                while (!token.IsCancellationRequested)
                {
                    await CheckAndDownloadAsync();
                    try { await Task.Delay(CheckInterval, token); } catch { return; }
                }
            }, token);
        }

        /// <summary>
        /// Procura e baixa uma versao nova. Devolve a versao pronta (ou null se ja esta na
        /// ultima / nao instalado / sem rede).
        /// </summary>
        public async Task<string?> CheckAndDownloadAsync()
        {
            if (!IsInstalled) return null;
            await _lock.WaitAsync();
            try
            {
                if (_ready != null) return PendingVersion;

                var info = await _manager.CheckForUpdatesAsync();
                if (info == null) return null;

                await _manager.DownloadUpdatesAsync(info);
                _ready = info;
                var version = PendingVersion!;
                Log.Info($"Atualizacao {version} baixada; aplica ao reiniciar.");
                UpdateReady?.Invoke(version);
                return version;
            }
            catch (Exception ex)
            {
                Log.Warning($"Atualizacao: falha ao checar/baixar ({ex.Message})");
                return null;
            }
            finally
            {
                _lock.Release();
            }
        }

        /// <summary>Fecha o DroidDeck, aplica a atualizacao baixada e abre de novo.</summary>
        public void ApplyAndRestart()
        {
            if (_ready == null) return;
            _manager.ApplyUpdatesAndRestart(_ready.TargetFullRelease);
        }
    }
}

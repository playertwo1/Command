using System;
using System.Threading;
using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace DroidDeck.Hubs
{
    public class DeckHub : Hub
    {
        private readonly IServiceProvider _services;

        // Nº de clientes conectados. O SystemMonitorService usa isto pra NÃO ficar
        // fazendo broadcast e poll de mídia (WinRT caro) quando ninguém está ouvindo.
        private static int _connectedCount = 0;
        public static int ConnectedCount => Volatile.Read(ref _connectedCount);

        public DeckHub(IServiceProvider services)
        {
            _services = services;
        }

        // Ao conectar (ou reconectar), envia o estado atual de cada integração só para este
        // cliente, pra UI não ficar desatualizada após reconexão / reinício do backend.
        public override async Task OnConnectedAsync()
        {
            Interlocked.Increment(ref _connectedCount);
            // Manda a grade física atual (o configurador web a usa no lugar de um seletor manual).
            if (_services.GetService(typeof(Services.StreamDeckConfigService)) is Services.StreamDeckConfigService cfg)
            {
                try
                {
                    var layout = cfg.GetLayout();
                    await Clients.Caller.SendAsync("ReceiveLayoutUpdate",
                        new { rows = layout.Rows, columns = layout.Columns });
                }
                catch { }
            }
            // Estado de cada provedor com estado ao vivo (Discord, OBS, Tuya, timers...).
            if (_services.GetService(typeof(Services.ActionExecutorService)) is Services.ActionExecutorService executor)
            {
                foreach (var provider in executor.StatefulProviders)
                {
                    try { await Clients.Caller.SendAsync(provider.StateEvent, provider.GetState()); }
                    catch { }
                }
            }
            // Botoes de dois estados ligados e valores dos botoes de informacao.
            if (_services.GetService(typeof(Services.ButtonToggleService)) is Services.ButtonToggleService toggles)
            {
                try { await Clients.Caller.SendAsync(Services.ButtonToggleService.Event, toggles.GetState()); }
                catch { }
            }
            if (_services.GetService(typeof(Services.InfoService)) is Services.InfoService info)
            {
                try
                {
                    await Clients.Caller.SendAsync(Services.InfoService.Event, info.GetState());
                    if (info.NowPlaying is { } np)
                        await Clients.Caller.SendAsync(Services.InfoService.NowPlayingEvent, np);
                }
                catch { }
            }
            // Perfil do app em foco, para o celular abrir ja no perfil certo.
            if (_services.GetService(typeof(Services.ForegroundWatcher)) is Services.ForegroundWatcher fg)
            {
                try { await Clients.Caller.SendAsync(Services.ForegroundWatcher.Event, fg.GetState()); }
                catch { }
            }
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            Interlocked.Decrement(ref _connectedCount);
            await base.OnDisconnectedAsync(exception);
        }
    }
}

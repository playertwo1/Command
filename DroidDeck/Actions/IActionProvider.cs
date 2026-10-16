using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading.Tasks;
using DroidDeck.Models;

namespace DroidDeck.Actions
{
    /// <summary>
    /// Um tipo de acao do deck (obs, discord, timer...). Cada provedor executa a acao,
    /// descreve os parametros que aceita (o editor do app monta o formulario a partir disso)
    /// e, se tiver estado ao vivo, o publica para os clientes.
    ///
    /// Para criar um tipo novo: implementar esta interface e registrar no DI
    /// (services.AddSingleton&lt;IActionProvider, MeuProvider&gt;). Nao precisa mexer no
    /// executor, no hub nem no editor -- a menos que a acao precise de uma tela propria.
    /// </summary>
    public interface IActionProvider
    {
        /// <summary>Valor de DeckAction.Type. Comparado sem diferenciar maiusculas.</summary>
        string Type { get; }

        /// <summary>Outros nomes aceitos para o mesmo tipo (ex.: "launchApp").</summary>
        IReadOnlyCollection<string> Aliases => Array.Empty<string>();

        ActionSchema Describe();

        Task ExecuteAsync(ActionContext context);
    }

    /// <summary>Provedor com estado ao vivo (OBS conectado, mudo do Discord, timers...).</summary>
    public interface IStatefulActionProvider : IActionProvider
    {
        /// <summary>Evento SignalR em que o estado vai (ex.: "ReceiveObsState").</summary>
        string StateEvent { get; }

        object GetState();
    }

    /// <summary>Uma execucao: a acao, o botao que a disparou (se houver) e utilitarios.</summary>
    public class ActionContext
    {
        public ActionContext(DeckAction action, string? buttonId, Func<DeckAction, string?, Task> execute)
        {
            Action = action;
            ButtonId = buttonId;
            _execute = execute;
        }

        private readonly Func<DeckAction, string?, Task> _execute;

        public DeckAction Action { get; }

        /// <summary>Id do botao apertado. Nulo em /execute avulso.</summary>
        public string? ButtonId { get; }

        public IDictionary<string, string> Parameters => Action.Parameters;

        public string Get(string key, string fallback = "") =>
            Parameters.TryGetValue(key, out var v) && v != null ? v : fallback;

        public string Operation(string fallback) =>
            (Get("operation") is { Length: > 0 } op ? op : fallback).Trim().ToLowerInvariant();

        public int Int(string key, int fallback) =>
            int.TryParse(Get(key), NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : fallback;

        public double Number(string key, double fallback) =>
            double.TryParse(Get(key), NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : fallback;

        /// <summary>Executa outra acao (multi-acao). O botao de origem e preservado.</summary>
        public Task ExecuteAsync(DeckAction action) => _execute(action, ButtonId);
    }
}

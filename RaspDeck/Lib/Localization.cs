using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace DroidDeck.Lib
{
    /// <summary>
    /// Traducao dos textos que o servidor manda para o app. O texto-fonte continua em portugues
    /// no codigo; L.T("...") devolve a versao em ingles quando a requisicao pediu ingles
    /// (Accept-Language: en...) e existe traducao em Localization.en.cs. Sem traducao, fica o
    /// portugues -- nunca quebra.
    ///
    /// O idioma e por requisicao (AsyncLocal), marcado pelo middleware UseLanguage. Fora de uma
    /// requisicao (servicos em segundo plano, SignalR) vale portugues.
    /// </summary>
    public static partial class L
    {
        private static readonly AsyncLocal<bool> _english = new();

        public static bool English
        {
            get => _english.Value;
            set => _english.Value = value;
        }

        public static string T(string pt) =>
            English && En.TryGetValue(pt, out var en) ? en : pt;

        /// <summary>Traduz e depois troca os {chave} pelos valores.</summary>
        public static string T(string pt, params (string key, object? value)[] args)
        {
            var text = T(pt);
            foreach (var (key, value) in args)
                text = text.Replace("{" + key + "}", value?.ToString() ?? "");
            return text;
        }

        /// <summary>Versao que aceita null (campos opcionais do schema).</summary>
        public static string? TOrNull(string? pt) => pt == null ? null : T(pt);

        /// <summary>Primeira preferencia do Accept-Language comeca com "en"?</summary>
        public static bool IsEnglish(string? acceptLanguage)
        {
            if (string.IsNullOrWhiteSpace(acceptLanguage)) return false;
            var first = acceptLanguage.Split(',')[0].Split(';')[0].Trim();
            return first.StartsWith("en", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>Marca o idioma da requisicao para L.T.</summary>
        public static IApplicationBuilder UseLanguage(this IApplicationBuilder app) =>
            app.Use(async (HttpContext ctx, Func<Task> next) =>
            {
                English = IsEnglish(ctx.Request.Headers.AcceptLanguage.ToString());
                await next();
            });
    }
}

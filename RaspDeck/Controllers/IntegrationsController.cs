using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Integrations;
using DroidDeck.Lib;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    /// <summary>
    /// Configuracao das integracoes com conta (homeassistant, spotify, twitch, youtube).
    /// O login OAuth acontece no navegador do PC; o retorno (callback) nao tem a chave da API
    /// e e validado pelo "state" que a propria integracao gerou.
    /// </summary>
    [Route("api/integrations")]
    [ApiController]
    public class IntegrationsController : ControllerBase
    {
        private readonly Dictionary<string, AccountIntegration> _integrations;

        public IntegrationsController(IEnumerable<AccountIntegration> integrations)
        {
            _integrations = integrations.ToDictionary(i => i.Name, StringComparer.OrdinalIgnoreCase);
        }

        [HttpGet("{name}")]
        public ActionResult<IntegrationStatus> Status(string name) =>
            _integrations.TryGetValue(name, out var i) ? Ok(Translated(i.GetStatus())) : NotFound();

        [HttpPost("{name}")]
        public async Task<ActionResult<IntegrationStatus>> Configure(string name, [FromBody] Dictionary<string, string>? fields)
        {
            if (!_integrations.TryGetValue(name, out var i)) return NotFound();
            try
            {
                return Ok(Translated(await i.ConfigureAsync(fields ?? new())));
            }
            catch (Exception ex)
            {
                var status = i.GetStatus();
                status.Message = ex.Message;
                return Ok(Translated(status));
            }
        }

        [HttpDelete("{name}")]
        public async Task<ActionResult> Logout(string name)
        {
            if (!_integrations.TryGetValue(name, out var i)) return NotFound();
            await i.LogoutAsync();
            return Ok(Translated(i.GetStatus()));
        }

        [HttpGet("{name}/options/{list}")]
        public async Task<ActionResult> Options(string name, string list)
        {
            if (!_integrations.TryGetValue(name, out var i)) return NotFound();
            try { return Ok(await i.OptionsAsync(list, Request.Query)); }
            catch (Exception ex) { return StatusCode(502, new { error = L.T(ex.Message) }); }
        }

        [AllowAnonymous]
        [HttpGet("{name}/callback")]
        public async Task<ContentResult> Callback(string name)
        {
            var html = _integrations.TryGetValue(name, out var i)
                ? await i.CallbackAsync(Request.Query)
                : L.T("Integração desconhecida.");
            return Content(html, "text/html; charset=utf-8");
        }

        /// <summary>
        /// As mensagens nascem dentro das integracoes (as vezes em segundo plano, sem idioma),
        /// entao a traducao e aqui, na saida. Texto com parte variavel fica em portugues.
        /// </summary>
        private static IntegrationStatus Translated(IntegrationStatus status)
        {
            if (status.Message != null) status.Message = L.T(status.Message);
            return status;
        }
    }
}

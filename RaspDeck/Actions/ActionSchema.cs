using System.Collections.Generic;
using System.Linq;

namespace DroidDeck.Actions
{
    /// <summary>
    /// Descricao de um tipo de acao para o editor do app, servida em GET /api/actions/schema.
    /// O app monta o formulario a partir dos campos; tipos com tela propria (Editor != null)
    /// usam so o titulo, o icone e a categoria daqui.
    /// </summary>
    public class ActionSchema
    {
        public string Type { get; set; } = "";
        public string Title { get; set; } = "";

        /// <summary>Nome de um icone Material (ex.: "videocam"). O app tem a tabela.</summary>
        public string Icon { get; set; } = "extension";

        /// <summary>Agrupa o seletor de tipo: Sistema, Midia, Streaming, Casa, Utilidades.</summary>
        public string Category { get; set; } = "Utilidades";

        public string? Description { get; set; }

        /// <summary>Executa codigo no PC: so pode ser criada ou alterada no configurador.</summary>
        public bool Privileged { get; set; }

        /// <summary>O botao reflete um estado ligado/desligado (tem "cor quando ativo").</summary>
        public bool Stateful { get; set; }

        /// <summary>Nome de uma tela propria no app (discord, tuya...). Null = formulario.</summary>
        public string? Editor { get; set; }

        /// <summary>
        /// Tela de configuracao da integracao no app (obs, discord, tuya, soundboard). Com ela,
        /// o editor avisa quando o estado do provedor nao esta "connected" e oferece o atalho.
        /// </summary>
        public string? Settings { get; set; }

        /// <summary>Evento SignalR do estado ao vivo, se o provedor tiver um.</summary>
        public string? StateEvent { get; set; }

        public List<ActionField> Fields { get; set; } = new();
    }

    public static class FieldKind
    {
        public const string Text = "text";
        public const string Multiline = "multiline";
        public const string Number = "number";
        public const string Select = "select";
        public const string Toggle = "toggle";
    }

    public class ActionField
    {
        public string Key { get; set; } = "";
        public string Label { get; set; } = "";
        public string Kind { get; set; } = FieldKind.Text;
        public string? Default { get; set; }
        public string? Help { get; set; }
        public string? Hint { get; set; }
        public bool Required { get; set; }

        /// <summary>Opcoes fixas de um select.</summary>
        public List<FieldOption>? Options { get; set; }

        /// <summary>
        /// Endpoint (GET, relativo ao servidor) que devolve as opcoes de um select: lista de
        /// strings ou de {value, label}. Aceita {chave} com o valor atual de outro campo,
        /// ex.: "/api/obs/filters?source={sourceName}".
        /// </summary>
        public string? OptionsSource { get; set; }

        /// <summary>Select que tambem aceita um valor digitado (fora da lista).</summary>
        public bool AllowCustom { get; set; }

        public double? Min { get; set; }
        public double? Max { get; set; }

        /// <summary>Sufixo exibido ao lado do numero (s, %, ms...).</summary>
        public string? Unit { get; set; }

        /// <summary>So aparece quando todos os campos indicados tem um dos valores listados.</summary>
        public Dictionary<string, string[]>? VisibleWhen { get; set; }

        // ---- Construtores curtos para os provedores ----

        public static ActionField Text(string key, string label, string? hint = null, string? help = null, bool required = false) =>
            new() { Key = key, Label = label, Kind = FieldKind.Text, Hint = hint, Help = help, Required = required };

        public static ActionField Multiline(string key, string label, string? hint = null, string? help = null) =>
            new() { Key = key, Label = label, Kind = FieldKind.Multiline, Hint = hint, Help = help };

        public static ActionField Number(string key, string label, double def, double? min = null, double? max = null, string? unit = null, string? help = null) =>
            new() { Key = key, Label = label, Kind = FieldKind.Number, Default = def.ToString(System.Globalization.CultureInfo.InvariantCulture), Min = min, Max = max, Unit = unit, Help = help };

        public static ActionField Toggle(string key, string label, bool def = false, string? help = null) =>
            new() { Key = key, Label = label, Kind = FieldKind.Toggle, Default = def ? "true" : "false", Help = help };

        public static ActionField Select(string key, string label, params (string value, string label)[] options) =>
            new()
            {
                Key = key,
                Label = label,
                Kind = FieldKind.Select,
                Default = options.Length > 0 ? options[0].value : null,
                Options = options.Select(o => new FieldOption(o.value, o.label)).ToList(),
            };

        public static ActionField Dynamic(string key, string label, string source, string? help = null, bool allowCustom = false) =>
            new() { Key = key, Label = label, Kind = FieldKind.Select, OptionsSource = source, Help = help, AllowCustom = allowCustom, Required = true };

        /// <summary>Mostra o campo so quando <paramref name="field"/> vale um de <paramref name="values"/>.</summary>
        public ActionField When(string field, params string[] values)
        {
            VisibleWhen ??= new Dictionary<string, string[]>();
            VisibleWhen[field] = values;
            return this;
        }

        public ActionField WithDefault(string value)
        {
            Default = value;
            return this;
        }
    }

    public class FieldOption
    {
        public FieldOption() { }

        public FieldOption(string value, string label)
        {
            Value = value;
            Label = label;
        }

        public string Value { get; set; } = "";
        public string Label { get; set; } = "";
    }
}

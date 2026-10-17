using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.Json;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    /// <summary>
    /// Backup dos perfis num arquivo .droiddeck: um zip com manifest.json e um JSON por
    /// perfil (os icones personalizados vao junto, em base64, dentro dos botoes).
    ///
    /// Importar e restaurar: um perfil com o mesmo id substitui o atual, os demais sao
    /// adicionados. Os ids sao mantidos para os botoes "abrir perfil" continuarem apontando
    /// para as pastas certas.
    /// </summary>
    public class BackupService
    {
        public const int FormatVersion = 1;
        public const long MaxSize = 50 * 1024 * 1024;

        private static readonly JsonSerializerOptions Json = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            WriteIndented = true,
        };

        private readonly StreamDeckConfigService _config;

        public BackupService(StreamDeckConfigService config) => _config = config;

        public byte[] Export()
        {
            var profiles = _config.GetProfiles();
            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
            {
                Write(zip, "manifest.json", new Manifest
                {
                    Format = FormatVersion,
                    App = "DroidDeck",
                    Version = typeof(BackupService).Assembly.GetName().Version?.ToString(3),
                    ExportedAt = DateTime.UtcNow,
                    Profiles = profiles.Count,
                });
                foreach (var p in profiles)
                    Write(zip, $"profiles/{p.Id}.json", p);
            }
            return ms.ToArray();
        }

        /// <summary>Le os perfis de um backup. Lanca InvalidDataException se o arquivo nao for um.</summary>
        public static List<DeckProfile> Read(Stream stream)
        {
            ZipArchive zip;
            try
            {
                zip = new ZipArchive(stream, ZipArchiveMode.Read);
            }
            catch (InvalidDataException)
            {
                throw new InvalidDataException("Não é um backup do DroidDeck (o arquivo não é um .droiddeck válido).");
            }

            try
            {
                using var _ = zip;
                var manifestEntry = zip.GetEntry("manifest.json")
                    ?? throw new InvalidDataException("Não é um backup do DroidDeck (falta o manifest.json).");
                Manifest? manifest;
                using (var s = manifestEntry.Open())
                    manifest = JsonSerializer.Deserialize<Manifest>(s, Json);
                if (manifest == null || manifest.App != "DroidDeck")
                    throw new InvalidDataException("Não é um backup do DroidDeck.");
                if (manifest.Format > FormatVersion)
                    throw new InvalidDataException("Backup de uma versão mais nova do DroidDeck. Atualize o DroidDeck no PC.");

                var profiles = new List<DeckProfile>();
                foreach (var entry in zip.Entries.Where(e => e.FullName.StartsWith("profiles/") && e.FullName.EndsWith(".json")))
                {
                    using var s = entry.Open();
                    var profile = JsonSerializer.Deserialize<DeckProfile>(s, Json);
                    if (profile != null && StreamDeckConfigService.IsValidProfileId(profile.Id))
                        profiles.Add(profile);
                }
                return profiles;
            }
            catch (InvalidDataException)
            {
                throw;
            }
            catch (Exception ex) when (ex is JsonException or IOException)
            {
                throw new InvalidDataException("Arquivo de backup corrompido.", ex);
            }
        }

        public int Import(IEnumerable<DeckProfile> profiles)
        {
            var count = 0;
            foreach (var p in profiles)
            {
                _config.SaveProfile(p);
                count++;
            }
            return count;
        }

        private static void Write(ZipArchive zip, string name, object value)
        {
            var entry = zip.CreateEntry(name, CompressionLevel.Optimal);
            using var s = entry.Open();
            JsonSerializer.Serialize(s, value, Json);
        }

        public class Manifest
        {
            public int Format { get; set; }
            public string? App { get; set; }
            public string? Version { get; set; }
            public DateTime ExportedAt { get; set; }
            public int Profiles { get; set; }
        }
    }
}

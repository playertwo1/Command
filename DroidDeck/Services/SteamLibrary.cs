using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace DroidDeck.Services
{
    /// <summary>
    /// Jogos instalados na Steam: le as bibliotecas (libraryfolders.vdf) e os manifestos
    /// (appmanifest_*.acf), e monta um icone quadrado a partir da capa que a Steam guarda
    /// em appcache/librarycache. Nada disso exige login nem rede.
    /// </summary>
    public class SteamLibrary
    {
        /// <summary>Ferramentas que a Steam instala como "apps" e nao sao jogos.</summary>
        private static readonly HashSet<string> NotGames = new() { "228980", "1070560", "1391110", "1628350", "1493710" };

        private static readonly Regex PathRx = new("\"path\"\\s+\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex AppIdRx = new("\"appid\"\\s+\"(\\d+)\"", RegexOptions.Compiled);
        private static readonly Regex NameRx = new("\"name\"\\s+\"([^\"]+)\"", RegexOptions.Compiled);

        public record Game(string AppId, string Name);

        public string? SteamPath
        {
            get
            {
                try
                {
                    using var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam");
                    var path = key?.GetValue("SteamPath") as string;
                    return path != null && Directory.Exists(path) ? Path.GetFullPath(path) : null;
                }
                catch
                {
                    return null;
                }
            }
        }

        public List<Game> Games()
        {
            var steam = SteamPath;
            if (steam == null) return new List<Game>();

            var libraries = new List<string> { steam };
            var vdf = Path.Combine(steam, "steamapps", "libraryfolders.vdf");
            if (File.Exists(vdf))
            {
                foreach (Match m in PathRx.Matches(File.ReadAllText(vdf)))
                    libraries.Add(m.Groups[1].Value.Replace(@"\\", @"\"));
            }

            var games = new Dictionary<string, Game>();
            foreach (var lib in libraries.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var apps = Path.Combine(lib, "steamapps");
                if (!Directory.Exists(apps)) continue;
                foreach (var acf in Directory.EnumerateFiles(apps, "appmanifest_*.acf"))
                {
                    try
                    {
                        var text = File.ReadAllText(acf);
                        var id = AppIdRx.Match(text).Groups[1].Value;
                        var name = NameRx.Match(text).Groups[1].Value;
                        if (id.Length == 0 || name.Length == 0 || NotGames.Contains(id)) continue;
                        if (name.Contains("Redistributable", StringComparison.OrdinalIgnoreCase) ||
                            name.StartsWith("Proton", StringComparison.OrdinalIgnoreCase) ||
                            name.StartsWith("Steam Linux Runtime", StringComparison.OrdinalIgnoreCase))
                            continue;
                        games[id] = new Game(id, name);
                    }
                    catch (IOException) { }
                }
            }
            return games.Values.OrderBy(g => g.Name, StringComparer.OrdinalIgnoreCase).ToList();
        }

        /// <summary>
        /// Icone quadrado (PNG em base64) para o botao: o miolo da capa vertical, ou a capa
        /// horizontal se a vertical nao estiver no cache. Null se a Steam ainda nao baixou
        /// nenhuma imagem do jogo.
        /// </summary>
        public string? IconBase64(string appId, int size = 192)
        {
            if (!Regex.IsMatch(appId, @"^\d+$")) return null;
            var steam = SteamPath;
            if (steam == null) return null;

            var cache = Path.Combine(steam, "appcache", "librarycache");
            var candidates = new[]
            {
                Path.Combine(cache, appId, "library_600x900.jpg"),
                Path.Combine(cache, $"{appId}_library_600x900.jpg"),
                Path.Combine(cache, appId, "header.jpg"),
                Path.Combine(cache, $"{appId}_header.jpg"),
            };
            var file = candidates.FirstOrDefault(File.Exists);
            if (file == null) return null;

            try
            {
                using var source = Image.FromFile(file);
                // Recorte quadrado no centro; numa capa vertical, um pouco acima do meio,
                // onde costuma ficar o personagem/arte principal.
                var side = Math.Min(source.Width, source.Height);
                var x = (source.Width - side) / 2;
                var y = source.Height > source.Width ? (source.Height - side) / 3 : (source.Height - side) / 2;

                using var bmp = new Bitmap(size, size);
                using (var g = Graphics.FromImage(bmp))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.SmoothingMode = SmoothingMode.HighQuality;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(source, new Rectangle(0, 0, size, size), new Rectangle(x, y, side, side), GraphicsUnit.Pixel);
                }
                using var ms = new MemoryStream();
                bmp.Save(ms, ImageFormat.Png);
                return Convert.ToBase64String(ms.ToArray());
            }
            catch
            {
                return null;
            }
        }
    }
}

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Command.Lib;

namespace Command.Services
{
    public sealed record DestinationFolder(string Id, string Name, string Icon, string Path);

    /// <summary>Pastas de destino nomeadas para uploads do celular (F1). O caminho nunca sai do PC.</summary>
    public interface IDestinationFolderStore
    {
        IReadOnlyList<DestinationFolder> List();
        string? TryGetPath(string id);
        DestinationFolder Add(string name, string icon, string path);
        bool Remove(string id);
    }

    public sealed class DestinationFolderStore : IDestinationFolderStore
    {
        private static readonly string[] ForbiddenNames = { "windows", "program files", "program files (x86)", "programdata" };

        // O formulário do tray e a Bridge precisam enxergar o mesmo cadastro.
        public static DestinationFolderStore Shared { get; } = new();

        private readonly object _gate = new();
        private readonly string _storagePath;
        private List<DestinationFolder> _items = new();

        public DestinationFolderStore(string? storagePath = null)
        {
            _storagePath = storagePath ?? Path.Combine(AppPaths.RoamingDir, "transfer_folders.json");
            try
            {
                if (File.Exists(_storagePath))
                    _items = JsonSerializer.Deserialize<List<DestinationFolder>>(File.ReadAllText(_storagePath)) ?? new();
            }
            catch (Exception) { _items = new(); } // arquivo corrompido: começa vazio, o inbound segue como padrão
        }

        public IReadOnlyList<DestinationFolder> List() { lock (_gate) return _items.ToList(); }

        public string? TryGetPath(string id)
        {
            lock (_gate) return _items.FirstOrDefault(i => i.Id == id)?.Path;
        }

        public DestinationFolder Add(string name, string icon, string path)
        {
            if (string.IsNullOrWhiteSpace(name) || name.Length > 40)
                throw new ArgumentException("Nome inválido (1 a 40 caracteres).");
            var full = Path.GetFullPath(path);
            if (!Directory.Exists(full)) throw new ArgumentException("A pasta não existe.");
            if (IsForbidden(full)) throw new ArgumentException("Esta pasta não pode ser usada como destino.");

            var item = new DestinationFolder(Guid.NewGuid().ToString("N"), name.Trim(), icon, full);
            lock (_gate) { _items.Add(item); Save(); }
            return item;
        }

        public bool Remove(string id)
        {
            lock (_gate)
            {
                if (_items.RemoveAll(i => i.Id == id) == 0) return false;
                Save();
                return true;
            }
        }

        // Raiz de unidade, pastas do sistema e a pasta de dados do próprio Command.
        private static bool IsForbidden(string full)
        {
            var trimmed = full.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (Path.GetPathRoot(full)!.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) == trimmed) return true;
            var segments = full.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (segments.Length <= 3 && ForbiddenNames.Contains(segments.Last().ToLowerInvariant())) return true;
            return full.StartsWith(AppPaths.LocalDir, StringComparison.OrdinalIgnoreCase)
                || full.StartsWith(AppPaths.RoamingDir, StringComparison.OrdinalIgnoreCase);
        }

        private void Save()
        {
            if (_storagePath == ":memory:") return;
            File.WriteAllText(_storagePath, JsonSerializer.Serialize(_items));
        }
    }
}

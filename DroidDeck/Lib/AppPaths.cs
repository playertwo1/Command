using System;
using System.IO;

namespace DroidDeck.Lib
{
    /// <summary>
    /// Pastas de dados do Command.
    ///   Local   (%LocalAppData%\Command): chave, segredos das integracoes, cache.
    ///   Roaming (%AppData%\Command):      perfis e grade.
    ///
    /// COMMAND_DATA_DIR troca as duas por uma pasta so (Roaming vira um subdiretorio).
    /// DROIDDECK_DATA_DIR continua aceito para os testes legados.
    /// </summary>
    public static class AppPaths
    {
        public const string DataDirEnvVar = "COMMAND_DATA_DIR";

        private static string? Override =>
            Environment.GetEnvironmentVariable(DataDirEnvVar) is { Length: > 0 } commandDir
                ? commandDir
                : Environment.GetEnvironmentVariable("DROIDDECK_DATA_DIR") is { Length: > 0 } legacyDir
                    ? legacyDir
                    : null;

        public static string LocalDir => Ensure(Override ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Command"));

        public static string RoamingDir => Ensure(Override is { } dir
            ? Path.Combine(dir, "Roaming")
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Command"));

        private static string Ensure(string dir)
        {
            Directory.CreateDirectory(dir);
            return dir;
        }
    }
}

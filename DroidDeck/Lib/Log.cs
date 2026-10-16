using System;
using System.IO;
using System.Runtime.InteropServices;

namespace DroidDeck.Lib
{
    public class Log
    {
        #region Constants
        private const bool GenerateStartingLogs = true;
        private const long MaxLogSize = 5 * 1024 * 1024;
        #endregion // Constants

        #region Attributes
        private static NLog.Logger _logger;
        #endregion // Attributes

        #region Constructors
        static Log()
        {
            try
            {
                // Load configuration from NLog.config (if present). Fall back to minimal programmatic config.
                var configFile = Path.Combine(AppContext.BaseDirectory, "NLog.config");
                if (File.Exists(configFile))
                {
                    NLog.LogManager.Configuration = new NLog.Config.XmlLoggingConfiguration(configFile);
                }
                else
                {
                    var config = new NLog.Config.LoggingConfiguration();
                    var logfile = new NLog.Targets.FileTarget("logfile")
                    {
                        FileName = GetPlaformFolder(),
                        Layout = "${longdate}|${level}|${message}|${exception:format=tostring}",
                        ArchiveAboveSize = MaxLogSize,
                        MaxArchiveFiles = 2
                    };
                    // Mesmas regras do NLog.config: das requisições do ASP.NET e do HttpClient, só avisos e erros.
                    config.AddRule(NLog.LogLevel.Info, NLog.LogLevel.Fatal, logfile, "Microsoft.Hosting.Lifetime", true);
                    config.AddRule(NLog.LogLevel.Trace, NLog.LogLevel.Info, new NLog.Targets.NullTarget(), "Microsoft.*", true);
                    config.AddRule(NLog.LogLevel.Trace, NLog.LogLevel.Info, new NLog.Targets.NullTarget(), "System.Net.Http.*", true);
                    config.AddRule(NLog.LogLevel.Info, NLog.LogLevel.Fatal, logfile);
                    NLog.LogManager.Configuration = config;
                }
            }
            catch
            {
                // Swallow - fallback to NLog default configuration
            }

            _logger = NLog.LogManager.GetCurrentClassLogger();
        }
        #endregion // Constructors

        #region Methods

        #region Trace
        public static void Trace(string message, params object[] parameters)
        {
            _logger.Trace(message, parameters);
        }

        public static void Trace(Exception exception, string message, params object[] parameters)
        {
            _logger.Trace(exception, message, parameters);
        }
        #endregion // Trace

        #region Debug
        public static void Debug(string message, params object[] parameters)
        {
            _logger.Debug(message, parameters);
        }

        public static void Debug(Exception exception, string message, params object[] parameters)
        {
            _logger.Debug(exception, message, parameters);
        }
        #endregion // Debug

        #region Info
        public static void Info(string message, params object[] parameters)
        {
            _logger.Info(message, parameters);
        }

        public static void Info(Exception exception, string message, params object[] parameters)
        {
            _logger.Info(exception, message, parameters);
        }
        #endregion // Info

        #region Warning
        public static void Warning(string message, params object[] parameters)
        {
            _logger.Warn(message, parameters);
        }

        public static void Warning(Exception exception, string message, params object[] parameters)
        {
            _logger.Warn(exception, message, parameters);
        }
        #endregion // Warning

        #region Error
        public static void Error(string message, params object[] parameters)
        {
            _logger.Error(message, parameters);
        }

        public static void Error(Exception exception, string message, params object[] parameters)
        {
            _logger.Error(exception, message, parameters);
        }
        #endregion // Error

        #region Critical
        public static void Critical(string message, params object[] parameters)
        {
            _logger.Fatal(message, parameters);
        }

        public static void Critical(Exception exception, string message, params object[] parameters)
        {
            _logger.Fatal(exception, message, parameters);
        }
        #endregion // Critical

        #endregion // Methods

        #region External Methods
        public static void UpdateLog(string logpath, bool generateLog, bool generateDetailed)
        {
            var config = new NLog.Config.LoggingConfiguration();
            NLog.Targets.Target target;
            var minLevel = generateDetailed ? NLog.LogLevel.Info : NLog.LogLevel.Warn;
            var maxLevel = NLog.LogLevel.Fatal;

            if (generateLog)
            {
                target = new NLog.Targets.FileTarget("logfile")
                {
                    FileName = Path.Combine(logpath, "DroidDeck.log"),
                    Layout = "${longdate}|${level}|${message}|${exception:format=tostring}"
                };
            }
            else
            {
                target = new NLog.Targets.NullTarget();
            }


            config.AddRule(minLevel, maxLevel, target);
            NLog.LogManager.Configuration = config;

            _logger = NLog.LogManager.GetCurrentClassLogger();
        }
        #endregion // External Methods

        #region Helper Methods
        /// <summary>
        /// Até a v1.9.0 o log nunca era dividido e chegava a centenas de MB. Esse arquivo antigo
        /// viraria um arquivo de histórico e ficaria no disco por meses; melhor apagar de uma vez.
        /// Chamar no começo do Main, antes de o NLog abrir o arquivo.
        /// </summary>
        public static void DropOversizedLegacyLog()
        {
            try
            {
                var path = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DroidDeck.log");
                var file = new FileInfo(path);                if (file.Exists && file.Length > 10 * MaxLogSize) file.Delete();
            }
            catch
            {
                // Em uso por outra instância ou sem permissão: fica para a próxima.
            }
        }

        private static string GetPlaformFolder()
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                return "${specialfolder:folder=UserProfile}/Library/Preferences/DroidDeck.log";

            return "${specialfolder:folder=LocalApplicationData}/DroidDeck.log";
        }
        #endregion
    }
}

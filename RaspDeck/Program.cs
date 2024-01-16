using System;
using System.Windows.Forms;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Mono.Zeroconf;

namespace AnyDeck
{
    static class Program
    {
        /// <summary>
        ///  The main entry point for the application.
        /// </summary>

        public static frmPrincipal FrmPrincipal { get; private set; }

        [STAThread]
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().RunAsync();

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            FrmPrincipal = new frmPrincipal();
            //RegisterService service = new RegisterService();
            //service.Name = "anydeck";
            //service.RegType = "_http._tcp";
            //service.ReplyDomain = "local.";
            //service.Port = 5000;
            //service.Register();

            Application.Run(FrmPrincipal);
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                });
    }
}

using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using DroidDeck.Auth;
using DroidDeck.Lib;

namespace DroidDeck
{
    /// <summary>
    /// Pareamento legado e emissão local de um ticket de controle remoto de uso único.
    /// </summary>
    public class frmPairing : Form
    {
        public frmPairing()
        {
            Text = L.Ui("Command — Parear dispositivo");
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(360, 500);

            var key = ApiKeyProvider.GetKey();
            var legacyPic = CreateQrPicture(PairingInfo.BuildUri());
            var controlUri = PairingInfo.BuildControlUri();
            var controlPic = CreateQrPicture(controlUri);
            var tabs = new TabControl { Location = new Point(8, 8), Size = new Size(344, 430) };
            var legacyPage = new TabPage(L.Ui("App atual"));
            legacyPage.Controls.Add(new Label
            {
                Text = L.Ui("Escaneie para conectar o app às funções atuais."),
                Location = new Point(8, 8), Size = new Size(320, 38),
                TextAlign = ContentAlignment.MiddleCenter,
            });
            legacyPic.Location = new Point(22, 48);
            legacyPage.Controls.Add(legacyPic);
            legacyPage.Controls.Add(new TextBox
            {
                Text = L.Ui("IP: {ip}    Chave: {key}", ("ip", $"{NetworkInfo.GetLanIp()}:{PairingInfo.Port}"), ("key", key)),
                Location = new Point(8, 354), Size = new Size(320, 44), Multiline = true,
                ReadOnly = true, BorderStyle = BorderStyle.None, BackColor = SystemColors.Control,
                TextAlign = HorizontalAlignment.Center,
            });

            var controlPage = new TabPage(L.Ui("Controle remoto"));
            controlPage.Controls.Add(new Label
            {
                Text = L.Ui("Ticket temporário de 2 minutos.\nEscaneie no app para autorizar este dispositivo."),
                Location = new Point(8, 8), Size = new Size(320, 48),
                TextAlign = ContentAlignment.MiddleCenter,
            });
            controlPic.Location = new Point(28, 58);
            controlPic.Size = new Size(280, 280);
            controlPage.Controls.Add(controlPic);
            controlPage.Controls.Add(new Label
            {
                Text = L.Ui("HTTPS: {ip}:{port}\nSe expirar, feche e reabra esta janela.",
                    ("ip", NetworkInfo.GetLanIp()), ("port", PairingInfo.ControlPort)),
                Location = new Point(8, 350), Size = new Size(320, 44),
                TextAlign = ContentAlignment.MiddleCenter,
            });
            tabs.TabPages.Add(legacyPage);
            tabs.TabPages.Add(controlPage);

            var close = new Button
            {
                Text = L.Ui("Fechar"),
                Location = new Point(140, 450),
                Size = new Size(80, 30),
            };
            close.Click += (_, _) => Close();
            AcceptButton = close;

            FormClosed += (_, _) =>
            {
                foreach (var picture in new[] { legacyPic, controlPic })
                {
                    var image = picture.Image;
                    picture.Image = null;
                    try { image?.Dispose(); } catch { }
                }
            };
            Controls.Add(tabs);
            Controls.Add(close);
        }

        private static PictureBox CreateQrPicture(string uri)
        {
            var picture = new PictureBox
            {
                Location = Point.Empty,
                Size = new Size(300, 300),
                SizeMode = PictureBoxSizeMode.Zoom,
            };
            try
            {
                // Bitmap must outlive the stream passed to its constructor.
                using var stream = new MemoryStream(PairingInfo.BuildQrPng(uri));
                using var qr = new Bitmap(stream);
                picture.Image = new Bitmap(qr);
            }
            catch (Exception ex)
            {
                Log.Error($"Falha ao gerar QR de pareamento: {ex.Message}");
            }
            return picture;
        }
    }
}

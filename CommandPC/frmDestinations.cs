using System;
using System.Drawing;
using System.Windows.Forms;
using Command.Lib;
using Command.Services;

namespace Command
{
    /// <summary>Cadastro das pastas de destino nomeadas que o celular pode escolher ao enviar arquivos.</summary>
    public class frmDestinations : Form
    {
        // Mesmos nomes que o app do celular mapeia para ícones.
        private static readonly string[] Icons = { "folder", "tv", "movie", "doc", "music", "image" };

        private readonly IDestinationFolderStore _store;
        private readonly ListBox _list = new() { Location = new Point(8, 8), Size = new Size(424, 200) };
        private readonly TextBox _name = new() { Location = new Point(8, 244), Size = new Size(200, 24), MaxLength = 40 };
        private readonly ComboBox _icon = new() { Location = new Point(216, 244), Size = new Size(100, 24), DropDownStyle = ComboBoxStyle.DropDownList };

        public frmDestinations(IDestinationFolderStore store)
        {
            _store = store;
            Text = L.Ui("Command — Pastas de destino");
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(440, 330);

            _icon.Items.AddRange(Icons);
            _icon.SelectedIndex = 0;

            var remove = new Button { Text = L.Ui("Remover selecionada"), Location = new Point(8, 210), Size = new Size(150, 26) };
            remove.Click += (_, _) =>
            {
                if (_list.SelectedIndex >= 0) _store.Remove(_store.List()[_list.SelectedIndex].Id);
                Reload();
            };

            var add = new Button { Text = L.Ui("Escolher pasta e adicionar…"), Location = new Point(8, 276), Size = new Size(200, 30) };
            add.Click += (_, _) => AddFolder();

            var close = new Button { Text = L.Ui("Fechar"), Location = new Point(352, 292), Size = new Size(80, 30) };
            close.Click += (_, _) => Close();
            AcceptButton = close;

            Controls.AddRange(new Control[]
            {
                _list, remove,
                new Label { Text = L.Ui("Nome (vazio = nome da pasta) e ícone:"), Location = new Point(8, 226), AutoSize = true },
                _name, _icon, add, close,
            });
            Reload();
        }

        private void Reload()
        {
            _list.Items.Clear();
            foreach (var d in _store.List()) _list.Items.Add($"{d.Name}  —  {d.Path}");
        }

        private void AddFolder()
        {
            using var dialog = new FolderBrowserDialog();
            if (dialog.ShowDialog(this) != DialogResult.OK) return;
            var name = string.IsNullOrWhiteSpace(_name.Text) ? new System.IO.DirectoryInfo(dialog.SelectedPath).Name : _name.Text;
            try
            {
                _store.Add(name, (string)_icon.SelectedItem!, dialog.SelectedPath);
                _name.Clear();
                Reload();
            }
            catch (ArgumentException ex)
            {
                MessageBox.Show(this, ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}

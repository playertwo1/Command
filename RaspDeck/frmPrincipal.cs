using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace AnyDeck
{
    public partial class frmPrincipal : Form
    {
        public frmPrincipal()
        {
            InitializeComponent();
        }

    private void frmPrincipal_Resize(object sender, EventArgs e)
    {
      if (WindowState == FormWindowState.Minimized)
      {
        ShowInTaskbar = false;
        ntiTray.Visible = true;
      }
    }

    private void ntiTray_Click(object sender, EventArgs e)
    {
      //
    }

    private void ntiTray_DoubleClick(object sender, EventArgs e)
    {
      ShowInTaskbar = true;
      WindowState = FormWindowState.Normal;
      ntiTray.Visible = false;
    }
  }
}

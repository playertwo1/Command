
namespace RaspDeck
{
  partial class frmPrincipal
  {
    /// <summary>
    ///  Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    ///  Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
      if (disposing && (components != null))
      {
        components.Dispose();
      }
      base.Dispose(disposing);
    }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(frmPrincipal));
            this.ntiTray = new System.Windows.Forms.NotifyIcon(this.components);
            this.SuspendLayout();
            // 
            // ntiTray
            // 
            this.ntiTray.BalloonTipTitle = "RaspDeck";
            this.ntiTray.Icon = ((System.Drawing.Icon)(resources.GetObject("ntiTray.Icon")));
            this.ntiTray.Text = "RaspDeck";
            this.ntiTray.Click += new System.EventHandler(this.ntiTray_Click);
            this.ntiTray.DoubleClick += new System.EventHandler(this.ntiTray_DoubleClick);
            // 
            // frmPrincipal
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 25F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(778, 424);
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Name = "frmPrincipal";
            this.Text = "RaspDeck";
            this.Resize += new System.EventHandler(this.frmPrincipal_Resize);
            this.ResumeLayout(false);

        }

    #endregion

    private System.Windows.Forms.NotifyIcon ntiTray;
  }
}


using Microsoft.AspNetCore.Mvc;
using RaspDeck.Software;
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace RaspDeck.Controllers
{
  [Route("api/[controller]")]
  [ApiController]
  public class SoftwareController : ControllerBase
  {
    [HttpPost("activate")]
    public IActionResult Activate([FromBody] SoftwareData data)
    {
      if (data.Name != null)
      {
        IntPtr window = FindWindow(null, data.Name);

        SetForegroundWindow(window);
      }
      SendKeys.SendWait(data.Action);
      return Ok();
    }

    [DllImport("USER32.DLL")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("USER32.DLL", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
  }
}

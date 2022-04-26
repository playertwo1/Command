using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RaspDeck.Software
{
  public class SoftwareData
  {
    private string name;
    private string action;

    public string Name { get => name; set => name = value; }
    public string Action { get => action; set => action = value; }
  }
}

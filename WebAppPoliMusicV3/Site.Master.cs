using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV3
{
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Solo usuarios autenticados pueden ver las paginas que usan la pagina maestra.
            if (!Request.IsAuthenticated)
            {
                Response.Redirect("~/Login.aspx", true);
            }
        }
    }
}
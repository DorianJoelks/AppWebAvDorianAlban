using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;

using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV2
{
    public partial class Song : System.Web.UI.Page
    {
        string strConnString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                try
                {
                    DataTable dtSong = new BLL.Song(strConnString).Read();
                    rptSongs.DataSource = dtSong;
                    rptSongs.DataBind();
                    lblMessage.Text = dtSong.Rows.Count == 0 ? "No songs available." : string.Empty;
                }
                catch (Exception ex)
                {
                    lblMessage.Text = "Could not load songs: " + ex.Message;
                }
            }
        }
    }
}

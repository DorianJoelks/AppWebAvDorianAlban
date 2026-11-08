using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV3
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
                    DataTable dtSong = new BLL.PoliMusicV3.Song(strConnString).Read();
                    gvSongs.DataSource = dtSong;
                    gvSongs.DataBind();
                    lblMessage.Text = string.Empty;
                }
                catch (Exception ex)
                {
                    lblMessage.Text = "No se pudieron cargar las canciones: " + ex.Message;
                }
            }
        }

        protected void gvSongs_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                DataRowView row = (DataRowView)e.Row.DataItem;
                e.Row.CssClass = "song";
                e.Row.Attributes["data-src"] = ResolveUrl(row["SONG_PATH"].ToString());
                e.Row.Attributes["data-title"] = row["SONG_NAME"].ToString();
                e.Row.Attributes["data-artist"] = row["ARTIST"].ToString();
            }
            else if (e.Row.RowType == DataControlRowType.Header)
            {
                e.Row.TableSection = TableRowSection.TableHeader;
            }
        }
    }
}
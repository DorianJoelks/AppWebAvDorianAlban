

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
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;

namespace WebAppPoliMusicV2.DAL
{
    public class Song
    {
        // Cadena de conexion a SQL Server (puerto 1434), definida en Web.config:
        // Data Source=localhost,1434;Initial Catalog=BDD_PoliMusic;...
        private string strConnectionString;
        public Song(string strConnString)
        {
            strConnectionString = strConnString;
        }

        /// <summary>
        /// Lista todas las canciones con su artista y album.
        /// </summary>
        public DataTable Read()
        {
            DataTable dtSong = new DataTable();
            using (SqlConnection con = new SqlConnection(strConnectionString))
            {
                string sentence =
                    "SELECT S.[ID_SONG], S.[SONG_NAME], S.[SONG_PATH], ISNULL(S.[PLAYS], 0) AS [PLAYS], " +
                    "       ISNULL(LTRIM(A.[ARTIST_NAME] + ' ' + ISNULL(A.[ARTIST_LASTNAME], '')), 'Unknown') AS [ARTIST], " +
                    "       ISNULL(AL.[TITLE_ALBUM], '') AS [ALBUM] " +
                    "FROM [TBL_SONG] S " +
                    "OUTER APPLY (SELECT TOP 1 AR.[ARTIST_NAME], AR.[ARTIST_LASTNAME] " +
                    "             FROM [TBL_PLAYER] P INNER JOIN [TBL_ARTIST] AR ON AR.[ID_ARTIST] = P.[ID_ARTIST] " +
                    "             WHERE P.[ID_SONG] = S.[ID_SONG] ORDER BY AR.[ID_ARTIST]) A " +
                    "OUTER APPLY (SELECT TOP 1 AB.[TITLE_ALBUM] " +
                    "             FROM [TBL_TRACKLIST] T INNER JOIN [TBL_ALBUM] AB ON AB.[ID_ALBUM] = T.[ID_ALBUM] " +
                    "             WHERE T.[ID_SONG] = S.[ID_SONG] ORDER BY AB.[ID_ALBUM]) AL " +
                    "ORDER BY S.[ID_SONG]";
                using (SqlCommand cmd = new SqlCommand(sentence, con))
                {
                    using (SqlDataAdapter sda = new SqlDataAdapter(cmd))
                    {
                        sda.Fill(dtSong);
                        return dtSong;
                    }
                }
            }
        }

        /// <summary>
        /// Incrementa el contador de reproducciones de una cancion.
        /// </summary>
        public int IncrementPlays(int idSong)
        {
            using (SqlConnection con = new SqlConnection(strConnectionString))
            {
                using (SqlCommand cmd = new SqlCommand("UPDATE [TBL_SONG] SET [PLAYS] = ISNULL([PLAYS], 0) + 1 WHERE [ID_SONG] = @ID_SONG", con))
                {
                    cmd.Parameters.AddWithValue("@ID_SONG", idSong);
                    con.Open();
                    return cmd.ExecuteNonQuery();
                }
            }
        }
    }
}

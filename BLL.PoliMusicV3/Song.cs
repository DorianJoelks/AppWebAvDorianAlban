using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BLL.PoliMusicV3
{
    public class Song
    {
        private string strConnectionString;
        public Song(string strConnString)
        {
            strConnectionString = strConnString;
        }
        public DataTable Read()
        {
            return new DAL.PoliMusicV3.Song(strConnectionString).Read();
        }
        public int IncrementPlays(int idSong)
        {
            return new DAL.PoliMusicV3.Song(strConnectionString).IncrementPlays(idSong);
        }
    }
}

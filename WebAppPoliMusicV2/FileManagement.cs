using System;
using System.Collections.Generic;
using System.IO;
using System.Web;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV2
{
    public class FileManagement : System.Web.UI.Page
    {
        /// <summary>
        /// Save a image on the server
        /// </summary>
        /// <param name="fileUpload">Object that contain the image</param>
        /// <param name="strFolder">Root folder</param>
        /// <param name="newFileName">Optional, if you want to use a custom name</param>
        /// <returns>Return an empty string if is OK or a error message</returns>
        public string SaveImageOnServer(FileUpload fileUpload, string strFolder, string newFileName)
        {
            try
            {
                string dataRequired = string.Empty;
                if (!fileUpload.HasFile)
                {
                    return "Image is required!!";
                }
                if (!(fileUpload.PostedFile.ContentType == "image/jpeg" ||
                    fileUpload.PostedFile.ContentType == "image/jpg" ||
                    fileUpload.PostedFile.ContentType == "image/png")
                    )
                {
                    return "Upload status: Only JPEG or PNG files are accepted!";
                }
                string fileExt = Path.GetExtension(fileUpload.FileName).ToLower();
                if (!(fileExt == ".jpg" || fileExt == ".jpeg" || fileExt == ".png"))
                {
                    return "Upload status: Only JPEG or PNG files are accepted!";
                }
                if (fileUpload.PostedFile.ContentLength > 10485760) //10MB=10485760Bytes
                {
                    return "Upload status: The file has to be less than 10 MB!";
                }
                string strServerFolder = Server.MapPath(strFolder);
                string strFileName;
                if (newFileName != string.Empty)
                {
                    strFileName = newFileName;
                }
                else
                {
                    strFileName = Path.GetFileNameWithoutExtension(fileUpload.FileName);
                }
                string strFileNameExtension = Path.GetExtension(fileUpload.FileName).ToLower();
                string newServerFileNameWithExtension = strServerFolder + strFileName + strFileNameExtension;

                // Create the directory if it does not exist.
                if (!Directory.Exists(strServerFolder))
                {
                    Directory.CreateDirectory(strServerFolder);
                }
                fileUpload.SaveAs(newServerFileNameWithExtension);
                return string.Empty;
            }
            catch (Exception ex)
            {
                return "Upload status: The file could not be uploaded. The following error occured: " + ex.Message;
            }
        }
        public string SaveDefaultImageOnServer(string strFolder, string newFileName)
        {
            try
            {
                string strServerFolder = Server.MapPath(strFolder);
                string strFileName = "default.jpg";
                string serverFileNameWithExtension = strServerFolder + strFileName;
                string servernewFileNameWithExtension = strServerFolder + newFileName + ".jpg";
                // Create the directory if it does not exist.
                if (Directory.Exists(strServerFolder))
                {
                    File.Copy(serverFileNameWithExtension, servernewFileNameWithExtension, true);
                }
                return string.Empty;
            }
            catch (Exception ex)
            {
                return "Upload status: The file could not be uploaded. The following error occured: " + ex.Message;
            }
        }
        public string SaveSongOnServer(FileUpload fileUpload, string strFolder, string newFileName)
        {
            try
            {
                string dataRequired = string.Empty;
                if (!fileUpload.HasFile)
                {
                    return "Select a song file first!!";
                }
                if (!(fileUpload.PostedFile.ContentType == "audio/mpeg" ||
                    fileUpload.PostedFile.ContentType == "audio/mpeg3" ||
                    fileUpload.PostedFile.ContentType == "audio/mp3")
                    )
                {
                    return "Upload status: The selected file must be a MP3 format!";
                }
                string strFileNameExtension = Path.GetExtension(fileUpload.FileName).ToLower();
                if (strFileNameExtension != ".mp3")
                {
                    return "Only .mp3 extensions are allowed to upload!!.";
                }
                string strmaxFileSize = System.Configuration.ConfigurationManager.AppSettings["maxSongLength"];
                int maxFileSize = string.IsNullOrEmpty(strmaxFileSize) ? 1024 : Convert.ToInt32(strmaxFileSize);//10485760
                if (fileUpload.PostedFile.ContentLength > maxFileSize)
                {
                    return "File size of the mp3 file is too large. Maximum file size permitted is " + maxFileSize / 1024 + "KB";
                }
                string strFileName;
                if (newFileName != string.Empty)
                {
                    strFileName = newFileName;
                }
                else
                {
                    strFileName = Path.GetFileNameWithoutExtension(fileUpload.FileName);
                }

                string strServerFolder = Server.MapPath(strFolder);
                string newServerFileNameWithExtension = strServerFolder + strFileName + strFileNameExtension;

                // Create the directory if it does not exist.
                if (!Directory.Exists(strServerFolder))
                {
                    Directory.CreateDirectory(strServerFolder);
                }
                fileUpload.SaveAs(newServerFileNameWithExtension);
                return string.Empty;
            }
            catch (Exception ex)
            {
                return "Upload status: The file could not be uploaded. The following error occured: " + ex.Message;
            }
        }
    }

}
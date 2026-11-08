using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV3
{
    public partial class SignUp : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        protected void btnSumbit_Click(object sender, EventArgs e)
        {
            string messageValidations = string.Empty;
            string userName = txtUserName.Text;
            string password = txtPassword.Text;
            string email = txtEmail.Text;
            string birthday = string.Empty;
            if (txtBirthDate.Text != string.Empty)
            {
                DateTime d;
                if (DateTime.TryParseExact(txtBirthDate.Text, "dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out d))
                {
                    birthday = d.ToString("yyyy-MM-dd");
                }
            }
            string photoName = fupPhoto.FileName;
            int type = EntityLayer.PoliMusicV3.Util.Constants.ID_USER_NORMAL;

            string newImageName = userName.Replace(" ", string.Empty);

            string strImageFolder = ConfigurationManager.AppSettings["userPhotoPath"];
            string strFileNameExtension = System.IO.Path.GetExtension(fupPhoto.FileName);
            string newFileNameWithExtension = strImageFolder + newImageName + strFileNameExtension;

            EntityLayer.PoliMusicV3.User user = new EntityLayer.PoliMusicV3.User();
            user.UserName = userName;
            user.Email = email;
            user.Password = password;
            user.Birthday = birthday;
            user.UserType = type;
            user.Photo = newFileNameWithExtension;

            string strConnString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
            messageValidations = UserFieldsRequiredValidations(user);
            if (messageValidations != string.Empty)
            {
                lblMessage.Text = messageValidations;
                return;
            }
            messageValidations = new BLL.PoliMusicV3.User(strConnString).ValidationsDuplicated(user);
            if (messageValidations != string.Empty)
            {
                lblMessage.Text = messageValidations;
                return;
            }
            if (fupPhoto.HasFile)
            {
                messageValidations = new FileManagement().SaveImageOnServer(fupPhoto, strImageFolder, newImageName);
            }
            else
            {
                messageValidations = new FileManagement().SaveDefaultImageOnServer(strImageFolder, newImageName);
                user.Photo += ".jpg";
            }
            if (messageValidations != string.Empty)
            {
                lblMessage.Text = messageValidations;
                return;
            }
            user.Password = EntityLayer.PoliMusicV3.Util.Hash.GeneratePasswordHash(password);
            new BLL.PoliMusicV3.User(strConnString).Save(user);
            lblMessage.Text = "User registered successfully!. Please go to login page.";
        }
        public string UserFieldsRequiredValidations(EntityLayer.PoliMusicV3.User user)
        {
            if (user.UserName == string.Empty)
            {
                return "Username is required!";
            }
            if (user.Email == string.Empty)
            {
                return "Email is required!";
            }
            if (user.Password == string.Empty)
            {
                return "Password is required!";
            }
            if (!IsValidEmail(user.Email))
            {
                return "Email is not valid!";
            }
            return string.Empty;
        }
        public static bool IsValidEmail(string email)
        {
            if (email == string.Empty || email.Replace(" ", "") == string.Empty)
                return false;

            try
            {
                // Normalize the domain
                email = Regex.Replace(email, @"(@)(.+)$", DomainMapper, RegexOptions.None);

                // Examines the domain part of the email and normalizes it.
                string DomainMapper(Match match)
                {
                    // Use IdnMapping class to convert Unicode domain names.
                    var idn = new IdnMapping();

                    // Pull out and process domain name (throws ArgumentException on invalid)
                    string domainName = idn.GetAscii(match.Groups[2].Value);

                    return match.Groups[1].Value + domainName;
                }
            }
            catch (Exception)
            {
                return false;
            }
            try
            {
                return Regex.IsMatch(email,
                    @"^[^@\s]+@[^@\s]+\.[^@\s]+$",
                    RegexOptions.IgnoreCase);
            }
            catch (Exception)
            {
                return false;
            }
        }
    }

}
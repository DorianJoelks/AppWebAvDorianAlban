using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace EntityLayer.PoliMusicV3.Util
{
    public class Hash
    {
        /// <summary>
        /// Generates a SHA1 hash of the specified input string.
        /// </summary>
        /// <param name="input">The input string to hash.</param>
        /// <returns>A hexadecimal string representation of the SHA1 hash.</returns>
        public static string GeneratePasswordHash(string input)
        {
            // Create a new instance of SHA1Managed to compute the hash
            using (SHA1Managed sha1 = new SHA1Managed())
            {
                // Compute the hash as a byte array from the UTF8-encoded input
                var hash = sha1.ComputeHash(Encoding.UTF8.GetBytes(input));
                // StringBuilder to build the hexadecimal string
                var sb = new StringBuilder(hash.Length * 2);

                // Convert each byte to its hexadecimal representation
                foreach (byte b in hash)
                {
                    // "X2" formats the byte as a two-character uppercase hexadecimal string
                    sb.Append(b.ToString("X2"));
                }
                // Return the complete hexadecimal hash string
                return sb.ToString();
            }
        }
        /// <summary>
        /// Generates a hashed password using PBKDF2 with a random 16-byte salt and 100,000 iterations.
        /// The result is a Base64 string containing the salt and hash.
        /// </summary>
        /// <param name="password">The plain text password to hash.</param>
        /// <returns>Base64-encoded string containing the salt and hash.</returns>
        public static string HashPassword(string password)
        {
            // Generate a 16-byte cryptographic salt
            byte[] salt;
            new RNGCryptoServiceProvider().GetBytes(salt = new byte[16]);

            // Derive a 20-byte hash using PBKDF2 with the password, salt, and 100,000 iterations
            var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 100000);
            byte[] hash = pbkdf2.GetBytes(20);

            // Combine the salt and hash into a single 36-byte array
            byte[] hashBytes = new byte[36];
            Array.Copy(salt, 0, hashBytes, 0, 16);
            Array.Copy(hash, 0, hashBytes, 16, 20);

            // Return the combined salt and hash as a Base64 string
            return Convert.ToBase64String(hashBytes);
        }
    }

}

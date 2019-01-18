using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Xml.Linq;

namespace IntuneWinAppUtilDecoder
{
    class Program
    {
        static void Main(string[] args)
        {
            var predefinedEncryptionKey = string.Empty;
            var predefinedInitializationVector = string.Empty;

            switch (args.Length)
            {
                case 0:
                    PrintUsage();
                    return;
                default:
                {
                    if (args.Length > 1)
                    {
                        foreach (var str in args)
                        {
                            if (str.StartsWith("/key:", StringComparison.OrdinalIgnoreCase))
                            {
                                predefinedEncryptionKey = str.Remove(0, 5);
                            }
                            if (str.StartsWith("/iv:", StringComparison.OrdinalIgnoreCase))
                            {
                                predefinedInitializationVector = str.Remove(0, 4);
                            }
                            if (string.Compare(str, "/s", StringComparison.OrdinalIgnoreCase) == 0 ||
                                string.Compare(str, "/silent", StringComparison.OrdinalIgnoreCase) == 0)
                            {
                                LogUtil.Silent = true;
                            }
                            }

                        if (string.IsNullOrWhiteSpace(predefinedEncryptionKey) ||
                            string.IsNullOrWhiteSpace(predefinedInitializationVector))
                        {
                            LogUtil.WriteLine("Encryption key and IV not found, use additional parameters /key: /iv:");
                        }
                    }

                    if (args.Length > 5)
                    {
                        LogUtil.WriteLine("Too many arguments!");
                        return;
                    }
                    break;
                }
            }

            var intunewinPath = args[0];
            string basePath;
            string targetFile;
            string extractPath;

            if (intunewinPath.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                intunewinPath.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                var webClient = new WebClient();
                var url = intunewinPath;
                var tempPath = Path.Combine(Path.GetTempPath(), Path.GetTempFileName());
                LogUtil.WriteLine($"http location specified, downloading .intunewin here: {tempPath}");
                LogUtil.Write($"downloading ...");
                webClient.DownloadFile(url, tempPath);
                LogUtil.WriteLine($" done!");
                intunewinPath = tempPath;
            }
            
            if (File.Exists(intunewinPath))
            {
                basePath = Path.GetDirectoryName(intunewinPath);
                if (basePath == null) return;

                targetFile = $"{intunewinPath}.decoded";
                extractPath = $"{basePath}\\extracted";

                if (File.Exists(targetFile))
                {
                    LogUtil.WriteLine("Do you want to overwrite the existing decoded and extracted files? [Y]|[N], Enter=Y");
                    var overwriteReply = LogUtil.ReadKey();
                    if (overwriteReply.Key == ConsoleKey.Y || overwriteReply.Key == ConsoleKey.Enter)
                    {
                        File.Delete(targetFile);
                        if (Directory.Exists($"{basePath}\\extracted"))
                        {
                            Directory.Delete($"{basePath}\\extracted", true);
                        }
                    }
                    else
                    {
                        LogUtil.WriteLine("...aborted!");
                        return;
                    }
                }
            }
            else
            {
                LogUtil.WriteLine("File does not exist!");
                return;
            }

            // we have the encrypted .intunewin and the decryption infos -> go and decrypt right away
            if (!string.IsNullOrWhiteSpace(predefinedEncryptionKey) &&
                !string.IsNullOrWhiteSpace(predefinedInitializationVector))
            {
                if (Decrypt(intunewinPath, targetFile, predefinedEncryptionKey, predefinedInitializationVector))
                {
                    LogUtil.WriteLine($"File '{intunewinPath}' successfully decoded!");
                }
#if DEBUG
                LogUtil.ReadKey();
#endif
            }
            else
            {
                // extract, read Detection.xml and decrypt
                try
                {
                    ZipFile.ExtractToDirectory(intunewinPath, extractPath);
                }
                catch (Exception e)
                {
                    LogUtil.WriteLine(e.Message);
                    return;
                }

                const string metadataPath = @"IntuneWinPackage\Metadata";
                const string contentsPath = @"IntuneWinPackage\Contents";

                var xmlFileName = $"{basePath}\\extracted\\{metadataPath}\\Detection.xml";
                var xml = XDocument.Load($"{xmlFileName}");

                if (xml.Root != null)
                {
                    var fileName = xml.Root.Element("FileName")?.Value;
                    var sourceFile = $"{basePath}\\extracted\\{contentsPath}\\{fileName}";
                    if (!File.Exists(sourceFile))
                    {
                        LogUtil.WriteLine("Encrypted source file does not exist!");
                        return;
                    }

                    var encryptionInfo = xml.Root.Element("EncryptionInfo");
                    if (encryptionInfo != null)
                    {
                        var encryptionKey = encryptionInfo.Element("EncryptionKey");
                        if (encryptionKey == null)
                        {
                            LogUtil.WriteLine("Could not load encryption key information!");
                            return;
                        }

                        var initializationVector = encryptionInfo.Element("InitializationVector");
                        if (initializationVector == null)
                        {
                            LogUtil.WriteLine("Could not load encryption IV information!");
                            return;
                        }

                        if (!Decrypt(sourceFile, targetFile, encryptionKey.Value, initializationVector.Value))
                            return;

                        LogUtil.WriteLine($"File '{fileName}' successfully decoded!");
                        LogUtil.WriteLine();
                        LogUtil.WriteLine("Do you want to cleanup the extracted files? [Y]|[N], Enter=Y");
                        var cleanupReply = LogUtil.ReadKey();
                        if (cleanupReply.Key == ConsoleKey.Y || cleanupReply.Key == ConsoleKey.Enter)
                        {
                            LogUtil.Write("Cleanup ...");
                            if (Directory.Exists($"{basePath}\\extracted"))
                            {
                                Directory.Delete($"{basePath}\\extracted", true);
                            }

                            LogUtil.WriteLine(" done!");
                        }
#if DEBUG
                        LogUtil.ReadKey();
#endif
                    }
                    else
                    {
                        LogUtil.WriteLine("Could not load decryption information!");
                    }
                }
                else
                {
                    LogUtil.WriteLine("Could not load 'detection.xml' file!");
                }
            }
        }

        private static bool Decrypt(string sourceFile, string targetFile, string keyBase64, string ivBase64)
        {
            var result = false;
            FileStream fileStreamTarget = null;
            Aes aes = null;
            try
            {
                aes = Aes.Create();
                byte[] buffer = new byte[2097152];

                fileStreamTarget = File.Open(targetFile, FileMode.Create, FileAccess.ReadWrite, FileShare.None);

                ICryptoTransform transform = null;
                FileStream fileStreamSource = null;
                CryptoStream cryptoStream = null;
                try
                {
                    LogUtil.Write("Processing ");

                    var key = Convert.FromBase64String(keyBase64);
                    var iv = Convert.FromBase64String(ivBase64);

                    transform = aes?.CreateDecryptor(key, iv);

                    fileStreamSource = File.Open(sourceFile, FileMode.Open, FileAccess.Read, FileShare.None);
                    cryptoStream = new CryptoStream(fileStreamTarget, transform, CryptoStreamMode.Write);

                    int count, tracker = 0;
                    while ((count = fileStreamSource.Read(buffer, 0, 2097152)) > 0)
                    {
                        cryptoStream.Write(buffer, 0, count);
                        cryptoStream.Flush();
                        tracker++;
                        if (tracker < 0)
                        {
                            LogUtil.Write(".");
                        }
                        else if (tracker % 10 == 0)
                        {
                            LogUtil.Write(".");
                        }
                    }

                    cryptoStream.FlushFinalBlock();
                    LogUtil.WriteLine(" done!");
                    result = true;
                }
                catch (Exception e)
                {
                    LogUtil.WriteLine(e.Message);
                }
                finally
                {
                    cryptoStream?.Dispose();
                    fileStreamSource?.Dispose();
                    transform?.Dispose();
                }
            }
            catch (Exception e)
            {
                LogUtil.WriteLine(e.Message);
            }
            finally
            {
                fileStreamTarget?.Dispose();
                aes?.Dispose();
            }

            return result;
        }

        private static void PrintUsage()
        {
            LogUtil.WriteLine();
            LogUtil.WriteLine("IntuneWinAppUtilDecoder by Oliver Kieselbach (oliverkieselbach.com)");
            LogUtil.WriteLine("This utility will decode an encrypted .intunewin package which was built with the");
            LogUtil.WriteLine("'Microsoft Intune Win32 App Packaging Tool' (https://github.com/Microsoft/Intune-Win32-App-Packaging-Tool)");
            LogUtil.WriteLine();
            LogUtil.WriteLine("USAGE: IntuneWinAppUtilDecoder.exe <FullPathToIntunewinFile> [/s | /silent] [/key:base64encodedKey /iv:base64encodedIV]");
            LogUtil.WriteLine();
            LogUtil.WriteLine("Examples");
            LogUtil.WriteLine("Interactive: IntuneWinAppUtilDecoder.exe \"C:\\Temp\\MyWin32Package.intunewin\"");
            LogUtil.WriteLine("Silent:      IntuneWinAppUtilDecoder.exe \"C:\\Temp\\MyWin32Package.intunewin\" /s");
            LogUtil.WriteLine("With Keys:   IntuneWinAppUtilDecoder.exe \"C:\\Temp\\EncryptedMyWin32Package.intunewin\" /key:AbC= /iv:XyZ==");
            LogUtil.WriteLine("");
            LogUtil.WriteLine("When using Key and IV parameter information you must provide a path to the encrypted .intunewin file.");
            LogUtil.WriteLine("This mode can also be combined with /silent parameter. URLs are also supported instead of file path for intunewin.");
#if DEBUG
            LogUtil.ReadKey();
#endif
        }
    }
}

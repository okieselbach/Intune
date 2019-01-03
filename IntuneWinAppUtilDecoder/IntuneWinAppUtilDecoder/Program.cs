using System;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Xml.Linq;

namespace IntuneWinAppUtilDecoder
{
    class Program
    {
        static void Main(string[] args)
        {
            switch (args.Length)
            {
                case 0:
                    PrintUsage();
                    return;
                case 2:
                {
                    if (string.Compare(args[1], "/s", StringComparison.OrdinalIgnoreCase) == 0 ||
                        string.Compare(args[1], "/silent", StringComparison.OrdinalIgnoreCase) == 0)
                    {
                        LogUtil.Silent = true;
                    }
                    break;
                }
                default:
                {
                    if (args.Length > 2)
                    {
                        LogUtil.WriteLine("Too many arguments!");
                        return;
                    }
                    break;
                }
            }

            var zipPath = args[0];
            string basePath;
            string targetFile;
            string extractPath;
            
            if (File.Exists(zipPath))
            {
                basePath = Path.GetDirectoryName(zipPath);
                if (basePath == null) return;

                targetFile = $"{zipPath}.decoded";
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

            try
            {
                ZipFile.ExtractToDirectory(zipPath, extractPath);
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

                            var key = Convert.FromBase64String(encryptionKey.Value);
                            var iv = Convert.FromBase64String(initializationVector.Value);
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
                        }
                        catch (Exception e)
                        {
                            LogUtil.WriteLine(e.Message);
                            return;
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
                        return;
                    }
                    finally
                    {
                        fileStreamTarget.Dispose();
                        aes?.Dispose();
                    }

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

        private static void PrintUsage()
        {
            LogUtil.WriteLine();
            LogUtil.WriteLine("IntuneWinAppUtilDecoder by Oliver Kieselbach (oliverkieselbach.com)");
            LogUtil.WriteLine("This utility will decode an encrypted .intunewin package which was built with the");
            LogUtil.WriteLine("'Microsoft Intune Win32 App Packaging Tool' (https://github.com/Microsoft/Intune-Win32-App-Packaging-Tool)");
            LogUtil.WriteLine();
            LogUtil.WriteLine("USAGE: IntuneWinAppUtilDecoder.exe <FullPathToIntunewinFile> [/s | /silent]");
            LogUtil.WriteLine();
            LogUtil.WriteLine("Example: IntuneWinAppUtilDecoder.exe \"C:\\Temp\\MyWin32Package.intunewin\"");
        }
    }
}

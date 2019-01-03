using System;

namespace IntuneWinAppUtilDecoder
{
    internal static class LogUtil
    {
        public static bool Silent { get; set; }

        public static void WriteLine(string text = "")
        {
            if (!Silent)
            {
                Console.WriteLine(text);
            }
        }

        public static void Write(string text = "")
        {
            if (!Silent)
            {
                Console.Write(text);
            }
        }

        public static ConsoleKeyInfo ReadKey()
        {
            return !Silent ? Console.ReadKey() : new ConsoleKeyInfo((char)13, ConsoleKey.Enter, false, false, false);
        }
    }
}

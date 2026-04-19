Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class InputSimulator
{
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    {
        public uint type;
        public MOUSEKEYBDHARDWAREUNION u;
    }
    
    [StructLayout(LayoutKind.Explicit)]
    struct MOUSEKEYBDHARDWAREUNION
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    
    #pragma warning disable 0649
    struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }
    #pragma warning restore 0649
    
    [DllImport("user32.dll")]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    
    [DllImport("user32.dll")]
    private static extern short VkKeyScan(char ch);
    
    private const int INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    
    public static void SendText(string text)
    {
        System.Threading.Thread.Sleep(100);
        var rnd = new Random();
        foreach (char c in text)
        {
            short vk = VkKeyScan(c);
            ushort keyCode = (ushort)(vk & 0xFF);
            bool shift = (vk & 0x100) != 0;
            
            var inputs = new INPUT[shift ? 4 : 2];
            int idx = 0;
            
            if (shift)
            {
                inputs[idx].type = INPUT_KEYBOARD;
                inputs[idx].u.ki.wVk = 0x10;
                idx++;
            }
            
            inputs[idx].type = INPUT_KEYBOARD;
            inputs[idx].u.ki.wVk = keyCode;
            idx++;
            
            inputs[idx].type = INPUT_KEYBOARD;
            inputs[idx].u.ki.wVk = keyCode;
            inputs[idx].u.ki.dwFlags = KEYEVENTF_KEYUP;
            idx++;
            
            if (shift)
            {
                inputs[idx].type = INPUT_KEYBOARD;
                inputs[idx].u.ki.wVk = 0x10;
                inputs[idx].u.ki.dwFlags = KEYEVENTF_KEYUP;
                idx++;
            }
            
            SendInput((uint)idx, inputs, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(rnd.Next(15, 40));
        }
    }
}
"@

function Send-SecureString {
    param([SecureString]$SecureString)
    $ptr = [Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plain = [Marshal]::PtrToStringBSTR($ptr)
        [InputSimulator]::SendText($plain)
    } finally {
        [Marshal]::ZeroFreeBSTR($ptr)
    }
}
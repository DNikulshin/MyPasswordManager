Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class KeyboardHook : NativeWindow, IDisposable
{
    private const int WM_HOTKEY = 0x0312;
    private const int MOD_ALT = 0x0001;
    private const int MOD_CONTROL = 0x0002;
    private const int MOD_SHIFT = 0x0004;
    private const int MOD_NOREPEAT = 0x4000;
    
    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    
    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    
    private int _currentId;
    public Action HotkeyPressed;
    
    public KeyboardHook()
    {
        this.CreateHandle(new CreateParams());
        _currentId = 0;
    }
    
    public void RegisterHotkey(Keys key, bool ctrl = false, bool shift = false, bool alt = false)
    {
        _currentId++;
        uint mods = MOD_NOREPEAT;
        if (ctrl)  mods |= MOD_CONTROL;
        if (shift) mods |= MOD_SHIFT;
        if (alt)   mods |= MOD_ALT;
        
        if (!RegisterHotKey(this.Handle, _currentId, mods, (uint)key))
            throw new InvalidOperationException("Горячая клавиша уже занята.");
    }
    
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY)
        {
            if (HotkeyPressed != null)
                HotkeyPressed();
        }
        base.WndProc(ref m);
    }
    
    public void Dispose()
    {
        for (int i = _currentId; i > 0; i--)
            UnregisterHotKey(this.Handle, i);
        this.DestroyHandle();
    }
}
"@ -ReferencedAssemblies "System.Windows.Forms"
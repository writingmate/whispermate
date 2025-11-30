using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;

namespace AIDictation.Services;

public class ClipboardService
{
    private static readonly Lazy<ClipboardService> _instance = new(() => new ClipboardService());
    public static ClipboardService Instance => _instance.Value;

    // Windows API for simulating keystrokes
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)]
        public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_V = 0x56;

    private ClipboardService() { }

    public void CopyToClipboard(string text)
    {
        try
        {
            Clipboard.SetText(text);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to copy to clipboard: {ex.Message}");
        }
    }

    public async Task PasteFromClipboard()
    {
        try
        {
            // Small delay to ensure clipboard is ready
            await Task.Delay(50);

            // Simulate Ctrl+V
            var inputs = new INPUT[4];

            // Ctrl down
            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].u.ki.wVk = VK_CONTROL;

            // V down
            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].u.ki.wVk = VK_V;

            // V up
            inputs[2].type = INPUT_KEYBOARD;
            inputs[2].u.ki.wVk = VK_V;
            inputs[2].u.ki.dwFlags = KEYEVENTF_KEYUP;

            // Ctrl up
            inputs[3].type = INPUT_KEYBOARD;
            inputs[3].u.ki.wVk = VK_CONTROL;
            inputs[3].u.ki.dwFlags = KEYEVENTF_KEYUP;

            SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to paste: {ex.Message}");
        }
    }

    public async Task CopyAndPaste(string text)
    {
        CopyToClipboard(text);

        if (SettingsService.Instance.AutoPaste)
        {
            await PasteFromClipboard();
        }
    }
}

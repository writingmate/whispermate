using System;
using System.Windows.Input;
using NHotkey;
using NHotkey.Wpf;

namespace AIDictation.Services;

public class HotkeyService : IDisposable
{
    private static readonly Lazy<HotkeyService> _instance = new(() => new HotkeyService());
    public static HotkeyService Instance => _instance.Value;

    private const string HotkeyName = "AIDictation_Record";

    public event EventHandler? HotkeyPressed;
    public event EventHandler? HotkeyReleased;

    public bool IsHotkeyRegistered { get; private set; }

    private HotkeyService()
    {
        // Load saved hotkey on startup
        var keyCode = SettingsService.Instance.HotkeyKeyCode;
        var modifiers = SettingsService.Instance.HotkeyModifiers;

        if (keyCode != 0)
        {
            RegisterHotkey((Key)keyCode, (ModifierKeys)modifiers);
        }
    }

    public bool RegisterHotkey(Key key, ModifierKeys modifiers)
    {
        try
        {
            // Unregister existing hotkey first
            UnregisterHotkey();

            HotkeyManager.Current.AddOrReplace(HotkeyName, key, modifiers, OnHotkeyPressed);

            // Save to settings
            SettingsService.Instance.HotkeyKeyCode = (int)key;
            SettingsService.Instance.HotkeyModifiers = (int)modifiers;

            IsHotkeyRegistered = true;
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to register hotkey: {ex.Message}");
            IsHotkeyRegistered = false;
            return false;
        }
    }

    public void UnregisterHotkey()
    {
        try
        {
            HotkeyManager.Current.Remove(HotkeyName);
            IsHotkeyRegistered = false;
        }
        catch
        {
            // Ignore - hotkey might not be registered
        }
    }

    private void OnHotkeyPressed(object? sender, HotkeyEventArgs e)
    {
        HotkeyPressed?.Invoke(this, EventArgs.Empty);
        e.Handled = true;
    }

    public string GetHotkeyDisplayString()
    {
        var keyCode = SettingsService.Instance.HotkeyKeyCode;
        var modifiers = (ModifierKeys)SettingsService.Instance.HotkeyModifiers;

        if (keyCode == 0)
        {
            return "Not set";
        }

        var key = (Key)keyCode;
        var parts = new System.Collections.Generic.List<string>();

        if (modifiers.HasFlag(ModifierKeys.Control))
            parts.Add("Ctrl");
        if (modifiers.HasFlag(ModifierKeys.Alt))
            parts.Add("Alt");
        if (modifiers.HasFlag(ModifierKeys.Shift))
            parts.Add("Shift");
        if (modifiers.HasFlag(ModifierKeys.Windows))
            parts.Add("Win");

        parts.Add(key.ToString());

        return string.Join(" + ", parts);
    }

    public void Dispose()
    {
        UnregisterHotkey();
    }
}

using System.Windows.Input;
using Newtonsoft.Json;

namespace AIDictation.Models;

public class Hotkey
{
    [JsonProperty("key")]
    public Key Key { get; set; }

    [JsonProperty("modifiers")]
    public ModifierKeys Modifiers { get; set; }

    [JsonProperty("mouseButton")]
    public int? MouseButton { get; set; }

    public Hotkey() { }

    public Hotkey(Key key, ModifierKeys modifiers = ModifierKeys.None)
    {
        Key = key;
        Modifiers = modifiers;
        MouseButton = null;
    }

    public Hotkey(int mouseButton)
    {
        Key = Key.None;
        Modifiers = ModifierKeys.None;
        MouseButton = mouseButton;
    }

    [JsonIgnore]
    public bool IsMouseButton => MouseButton.HasValue;

    [JsonIgnore]
    public string DisplayString
    {
        get
        {
            if (MouseButton.HasValue)
            {
                return MouseButton.Value switch
                {
                    2 => "🖱️ Middle Click",
                    3 => "🖱️ Side Button 1",
                    4 => "🖱️ Side Button 2",
                    _ => $"🖱️ Button {MouseButton.Value}"
                };
            }

            var parts = new List<string>();

            if (Modifiers.HasFlag(ModifierKeys.Control))
                parts.Add("Ctrl");
            if (Modifiers.HasFlag(ModifierKeys.Alt))
                parts.Add("Alt");
            if (Modifiers.HasFlag(ModifierKeys.Shift))
                parts.Add("Shift");
            if (Modifiers.HasFlag(ModifierKeys.Windows))
                parts.Add("Win");

            if (Key != Key.None)
                parts.Add(GetKeyDisplayName(Key));

            return string.Join(" + ", parts);
        }
    }

    private static string GetKeyDisplayName(Key key) => key switch
    {
        Key.OemPlus => "+",
        Key.OemMinus => "-",
        Key.OemPeriod => ".",
        Key.OemComma => ",",
        Key.Space => "Space",
        Key.Return => "Enter",
        Key.Back => "Backspace",
        Key.Escape => "Esc",
        Key.Tab => "Tab",
        Key.Left => "←",
        Key.Right => "→",
        Key.Up => "↑",
        Key.Down => "↓",
        _ when key >= Key.F1 && key <= Key.F24 => key.ToString(),
        _ when key >= Key.D0 && key <= Key.D9 => ((int)key - (int)Key.D0).ToString(),
        _ when key >= Key.NumPad0 && key <= Key.NumPad9 => $"Num{(int)key - (int)Key.NumPad0}",
        _ => key.ToString()
    };

    public override bool Equals(object? obj)
    {
        if (obj is not Hotkey other) return false;
        return Key == other.Key && 
               Modifiers == other.Modifiers && 
               MouseButton == other.MouseButton;
    }

    public override int GetHashCode() => HashCode.Combine(Key, Modifiers, MouseButton);
}

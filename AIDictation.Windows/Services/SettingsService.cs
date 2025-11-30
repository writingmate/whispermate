using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace AIDictation.Services;

public class SettingsService
{
    private static readonly Lazy<SettingsService> _instance = new(() => new SettingsService());
    public static SettingsService Instance => _instance.Value;

    private readonly string _settingsPath;
    private SettingsData _settings;

    private SettingsService()
    {
        var appDataFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "AIDictation"
        );
        Directory.CreateDirectory(appDataFolder);

        _settingsPath = Path.Combine(appDataFolder, "settings.json");
        _settings = LoadSettings();
    }

    // MARK: - Properties

    public bool HasCompletedOnboarding
    {
        get => _settings.HasCompletedOnboarding;
        set { _settings.HasCompletedOnboarding = value; Save(); }
    }

    public string ApiKey
    {
        get => _settings.ApiKey ?? string.Empty;
        set { _settings.ApiKey = value; Save(); }
    }

    public int SelectedAudioDevice
    {
        get => _settings.SelectedAudioDevice;
        set { _settings.SelectedAudioDevice = value; Save(); }
    }

    public string SelectedLanguage
    {
        get => _settings.SelectedLanguage ?? "auto";
        set { _settings.SelectedLanguage = value; Save(); }
    }

    public int HotkeyKeyCode
    {
        get => _settings.HotkeyKeyCode;
        set { _settings.HotkeyKeyCode = value; Save(); }
    }

    public int HotkeyModifiers
    {
        get => _settings.HotkeyModifiers;
        set { _settings.HotkeyModifiers = value; Save(); }
    }

    public bool AutoPaste
    {
        get => _settings.AutoPaste;
        set { _settings.AutoPaste = value; Save(); }
    }

    public bool LaunchAtStartup
    {
        get => _settings.LaunchAtStartup;
        set { _settings.LaunchAtStartup = value; Save(); }
    }

    public bool MuteAudioWhenRecording
    {
        get => _settings.MuteAudioWhenRecording;
        set { _settings.MuteAudioWhenRecording = value; Save(); }
    }

    // MARK: - Dictionary Entries

    public List<DictionaryEntry> DictionaryEntries
    {
        get => _settings.DictionaryEntries ?? new List<DictionaryEntry>();
        set { _settings.DictionaryEntries = value; Save(); }
    }

    public void AddDictionaryEntry(string trigger, string replacement)
    {
        var entries = DictionaryEntries;
        entries.Add(new DictionaryEntry { Trigger = trigger, Replacement = replacement, IsEnabled = true });
        DictionaryEntries = entries;
    }

    public void RemoveDictionaryEntry(int index)
    {
        var entries = DictionaryEntries;
        if (index >= 0 && index < entries.Count)
        {
            entries.RemoveAt(index);
            DictionaryEntries = entries;
        }
    }

    // MARK: - Prompt Rules (Context Rules)

    public List<PromptRule> PromptRules
    {
        get => _settings.PromptRules ?? new List<PromptRule>();
        set { _settings.PromptRules = value; Save(); }
    }

    public void AddPromptRule(string rule)
    {
        var rules = PromptRules;
        rules.Add(new PromptRule { Text = rule, IsEnabled = true });
        PromptRules = rules;
    }

    public void RemovePromptRule(int index)
    {
        var rules = PromptRules;
        if (index >= 0 && index < rules.Count)
        {
            rules.RemoveAt(index);
            PromptRules = rules;
        }
    }

    public void TogglePromptRule(int index)
    {
        var rules = PromptRules;
        if (index >= 0 && index < rules.Count)
        {
            rules[index].IsEnabled = !rules[index].IsEnabled;
            PromptRules = rules;
        }
    }

    public string GetPromptRules()
    {
        var enabledRules = PromptRules.FindAll(r => r.IsEnabled);
        if (enabledRules.Count == 0) return string.Empty;

        return string.Join(". ", enabledRules.ConvertAll(r => r.Text));
    }

    // MARK: - Voice Shortcuts

    public List<VoiceShortcut> Shortcuts
    {
        get => _settings.Shortcuts ?? new List<VoiceShortcut>();
        set { _settings.Shortcuts = value; Save(); }
    }

    public void AddShortcut(string voiceTrigger, string expansion)
    {
        var shortcuts = Shortcuts;
        shortcuts.Add(new VoiceShortcut { VoiceTrigger = voiceTrigger, Expansion = expansion, IsEnabled = true });
        Shortcuts = shortcuts;
    }

    public void RemoveShortcut(int index)
    {
        var shortcuts = Shortcuts;
        if (index >= 0 && index < shortcuts.Count)
        {
            shortcuts.RemoveAt(index);
            Shortcuts = shortcuts;
        }
    }

    // MARK: - Persistence

    private SettingsData LoadSettings()
    {
        try
        {
            if (File.Exists(_settingsPath))
            {
                var json = File.ReadAllText(_settingsPath);
                return JsonSerializer.Deserialize<SettingsData>(json) ?? new SettingsData();
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to load settings: {ex.Message}");
        }
        return new SettingsData();
    }

    private void Save()
    {
        try
        {
            var json = JsonSerializer.Serialize(_settings, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            File.WriteAllText(_settingsPath, json);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to save settings: {ex.Message}");
        }
    }
}

// MARK: - Data Models

public class SettingsData
{
    public bool HasCompletedOnboarding { get; set; }
    public string? ApiKey { get; set; }
    public int SelectedAudioDevice { get; set; }
    public string? SelectedLanguage { get; set; } = "auto";
    public int HotkeyKeyCode { get; set; }
    public int HotkeyModifiers { get; set; }
    public bool AutoPaste { get; set; } = true;
    public bool LaunchAtStartup { get; set; }
    public bool MuteAudioWhenRecording { get; set; } = true;
    public List<DictionaryEntry>? DictionaryEntries { get; set; }
    public List<PromptRule>? PromptRules { get; set; }
    public List<VoiceShortcut>? Shortcuts { get; set; }
}

public class DictionaryEntry
{
    public string Trigger { get; set; } = string.Empty;
    public string Replacement { get; set; } = string.Empty;
    public bool IsEnabled { get; set; } = true;
}

public class PromptRule
{
    public string Text { get; set; } = string.Empty;
    public bool IsEnabled { get; set; } = true;
}

public class VoiceShortcut
{
    public string VoiceTrigger { get; set; } = string.Empty;
    public string Expansion { get; set; } = string.Empty;
    public bool IsEnabled { get; set; } = true;
}

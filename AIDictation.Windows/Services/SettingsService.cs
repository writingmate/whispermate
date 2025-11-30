using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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

    public List<string> SelectedLanguages
    {
        get => _settings.SelectedLanguages ?? new List<string> { "auto" };
        set { _settings.SelectedLanguages = value; Save(); }
    }

    public void ToggleLanguage(string languageCode)
    {
        var languages = SelectedLanguages;

        if (languageCode == "auto")
        {
            // If selecting auto-detect, clear all others
            languages = new List<string> { "auto" };
        }
        else
        {
            // Remove auto-detect if selecting a specific language
            languages.Remove("auto");

            if (languages.Contains(languageCode))
            {
                languages.Remove(languageCode);
                // If no languages left, default to auto
                if (languages.Count == 0)
                {
                    languages.Add("auto");
                }
            }
            else
            {
                languages.Add(languageCode);
            }
        }

        SelectedLanguages = languages;
    }

    public bool IsLanguageSelected(string languageCode)
    {
        return SelectedLanguages.Contains(languageCode);
    }

    public string GetApiLanguageCode()
    {
        var languages = SelectedLanguages;
        if (languages.Contains("auto"))
        {
            return "auto";
        }

        // Return all selected language codes, comma-separated
        var languageCodes = languages.Where(lang => lang != "auto").OrderBy(lang => lang).ToList();
        return languageCodes.Count == 0 ? "auto" : string.Join(",", languageCodes);
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

    public bool ShowOverlayWhenIdle
    {
        get => _settings.ShowOverlayWhenIdle;
        set { _settings.ShowOverlayWhenIdle = value; Save(); }
    }

    public string OverlayPosition
    {
        get => _settings.OverlayPosition ?? "Top";
        set { _settings.OverlayPosition = value; Save(); }
    }

    public bool IncludeScreenContext
    {
        get => _settings.IncludeScreenContext;
        set { _settings.IncludeScreenContext = value; Save(); }
    }

    // MARK: - Authentication

    public bool IsAuthenticated
    {
        get => _settings.IsAuthenticated;
        set { _settings.IsAuthenticated = value; Save(); }
    }

    public string UserEmail
    {
        get => _settings.UserEmail ?? string.Empty;
        set { _settings.UserEmail = value; Save(); }
    }

    public SubscriptionTier SubscriptionTier
    {
        get => _settings.SubscriptionTier;
        set { _settings.SubscriptionTier = value; Save(); }
    }

    public int MonthlyWordCount
    {
        get => _settings.MonthlyWordCount;
        set { _settings.MonthlyWordCount = value; Save(); }
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
                var settings = JsonSerializer.Deserialize<SettingsData>(json) ?? new SettingsData();

                // Migrate from old SelectedLanguage (string) to SelectedLanguages (List<string>)
                // This will be handled by the property getter defaulting to new List { "auto" }
                // if SelectedLanguages is null

                return settings;
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

public enum SubscriptionTier
{
    Free,
    Pro
}

public class SettingsData
{
    public bool HasCompletedOnboarding { get; set; }
    public string? ApiKey { get; set; }
    public int SelectedAudioDevice { get; set; }
    public List<string>? SelectedLanguages { get; set; }
    public int HotkeyKeyCode { get; set; }
    public int HotkeyModifiers { get; set; }
    public bool AutoPaste { get; set; } = true;
    public bool LaunchAtStartup { get; set; }
    public bool MuteAudioWhenRecording { get; set; } = true;
    public bool ShowOverlayWhenIdle { get; set; } = true;
    public string? OverlayPosition { get; set; } = "Top";
    public bool IncludeScreenContext { get; set; }
    public bool IsAuthenticated { get; set; }
    public string? UserEmail { get; set; }
    public SubscriptionTier SubscriptionTier { get; set; }
    public int MonthlyWordCount { get; set; }
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

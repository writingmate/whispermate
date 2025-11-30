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

    // Properties
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

public class SettingsData
{
    public bool HasCompletedOnboarding { get; set; }
    public string? ApiKey { get; set; }
    public int SelectedAudioDevice { get; set; }
    public string? SelectedLanguage { get; set; } = "auto";
    public int HotkeyKeyCode { get; set; }
    public int HotkeyModifiers { get; set; }
    public bool AutoPaste { get; set; } = true;
    public List<PromptRule>? PromptRules { get; set; }
}

public class PromptRule
{
    public string Text { get; set; } = string.Empty;
    public bool IsEnabled { get; set; } = true;
}

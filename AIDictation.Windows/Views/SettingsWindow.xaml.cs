using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using AIDictation.Services;
using Microsoft.Win32;

namespace AIDictation.Views;

public partial class SettingsWindow : Window
{
    private bool _isCapturingHotkey = false;
    private Key _capturedKey = Key.None;
    private ModifierKeys _capturedModifiers = ModifierKeys.None;

    public SettingsWindow()
    {
        InitializeComponent();

        PreviewKeyDown += OnPreviewKeyDown;

        LoadSettings();
    }

    private void LoadSettings()
    {
        // Load General settings
        CurrentHotkeyDisplay.Text = HotkeyService.Instance.GetHotkeyDisplayString();
        LaunchAtStartupCheck.IsChecked = SettingsService.Instance.LaunchAtStartup;
        AutoPasteCheck.IsChecked = SettingsService.Instance.AutoPaste;

        // Load audio devices
        var devices = AudioRecordingService.GetAudioDevices();
        AudioDeviceCombo.Items.Clear();
        for (int i = 0; i < devices.Length; i++)
        {
            AudioDeviceCombo.Items.Add(devices[i].ProductName);
        }
        if (devices.Length > 0)
        {
            AudioDeviceCombo.SelectedIndex = SettingsService.Instance.SelectedAudioDevice;
        }

        // Load mute audio setting
        MuteAudioCheck.IsChecked = SettingsService.Instance.MuteAudioWhenRecording;

        // Load language
        var lang = SettingsService.Instance.SelectedLanguage;
        switch (lang)
        {
            case "en": LangEn.IsChecked = true; break;
            case "ru": LangRu.IsChecked = true; break;
            case "de": LangDe.IsChecked = true; break;
            case "fr": LangFr.IsChecked = true; break;
            case "es": LangEs.IsChecked = true; break;
            case "it": LangIt.IsChecked = true; break;
            case "pt": LangPt.IsChecked = true; break;
            case "zh": LangZh.IsChecked = true; break;
            case "ja": LangJa.IsChecked = true; break;
            case "ko": LangKo.IsChecked = true; break;
            default: LangAuto.IsChecked = true; break;
        }

        // Load rules
        RefreshRulesList();

        // Load API key (masked)
        var apiKey = SettingsService.Instance.ApiKey;
        if (!string.IsNullOrEmpty(apiKey))
        {
            ApiKeyPasswordBox.Password = apiKey;
        }
    }

    private void Tab_Checked(object sender, RoutedEventArgs e)
    {
        if (GeneralPanel == null) return;

        GeneralPanel.Visibility = GeneralTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AccountPanel.Visibility = AccountTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        PermissionsPanel.Visibility = PermissionsTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AudioPanel.Visibility = AudioTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        LanguagePanel.Visibility = LanguageTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        RulesPanel.Visibility = RulesTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    // General Tab
    private void HotkeyBox_Click(object sender, MouseButtonEventArgs e)
    {
        _isCapturingHotkey = true;
        CurrentHotkeyDisplay.Text = "Press your hotkey...";
        CurrentHotkeyDisplay.Foreground = (Brush)FindResource("PrimaryBrush");
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (!_isCapturingHotkey) return;

        if (e.Key == Key.LeftCtrl || e.Key == Key.RightCtrl ||
            e.Key == Key.LeftAlt || e.Key == Key.RightAlt ||
            e.Key == Key.LeftShift || e.Key == Key.RightShift ||
            e.Key == Key.LWin || e.Key == Key.RWin ||
            e.Key == Key.System)
        {
            return;
        }

        _capturedKey = e.Key;
        _capturedModifiers = Keyboard.Modifiers;

        if (HotkeyService.Instance.RegisterHotkey(_capturedKey, _capturedModifiers))
        {
            CurrentHotkeyDisplay.Text = HotkeyService.Instance.GetHotkeyDisplayString();
            CurrentHotkeyDisplay.Foreground = (Brush)FindResource("TextPrimaryBrush");
        }
        else
        {
            CurrentHotkeyDisplay.Text = "Failed to register hotkey";
            CurrentHotkeyDisplay.Foreground = (Brush)FindResource("ErrorBrush");
        }

        _isCapturingHotkey = false;
        e.Handled = true;
    }

    private void LaunchAtStartup_Changed(object sender, RoutedEventArgs e)
    {
        var enable = LaunchAtStartupCheck.IsChecked == true;
        SettingsService.Instance.LaunchAtStartup = enable;
        SetStartupRegistryKey(enable);
    }

    private void SetStartupRegistryKey(bool enable)
    {
        try
        {
            const string keyName = "AIDictation";
            using var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);

            if (enable)
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (!string.IsNullOrEmpty(exePath))
                {
                    key?.SetValue(keyName, $"\"{exePath}\"");
                }
            }
            else
            {
                key?.DeleteValue(keyName, false);
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to set startup registry: {ex.Message}");
        }
    }

    private void AutoPaste_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.AutoPaste = AutoPasteCheck.IsChecked == true;
    }

    // Account Tab
    private void SaveApiKey_Click(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.ApiKey = ApiKeyPasswordBox.Password.Trim();
        MessageBox.Show("API key saved successfully.", "Saved", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void ResetApp_Click(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            "Are you sure you want to reset the application? This will clear all settings and data.",
            "Reset Application",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            // Clear settings file
            var settingsPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "AIDictation",
                "settings.json"
            );
            if (File.Exists(settingsPath))
            {
                File.Delete(settingsPath);
            }

            // Clear history
            HistoryService.Instance.ClearHistory();

            // Remove startup registry
            SetStartupRegistryKey(false);

            MessageBox.Show("Application has been reset. Please restart the application.", "Reset Complete",
                MessageBoxButton.OK, MessageBoxImage.Information);

            Close();
        }
    }

    // Permissions Tab
    private void OpenMicrophoneSettings_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "ms-settings:privacy-microphone",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to open settings: {ex.Message}");
        }
    }

    // Audio Tab
    private void AudioDevice_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (AudioDeviceCombo.SelectedIndex >= 0)
        {
            SettingsService.Instance.SelectedAudioDevice = AudioDeviceCombo.SelectedIndex;
        }
    }

    private void MuteAudio_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.MuteAudioWhenRecording = MuteAudioCheck.IsChecked == true;
    }

    // Language Tab
    private void Language_Checked(object sender, RoutedEventArgs e)
    {
        string lang = "auto";
        if (LangEn.IsChecked == true) lang = "en";
        else if (LangRu.IsChecked == true) lang = "ru";
        else if (LangDe.IsChecked == true) lang = "de";
        else if (LangFr.IsChecked == true) lang = "fr";
        else if (LangEs.IsChecked == true) lang = "es";
        else if (LangIt.IsChecked == true) lang = "it";
        else if (LangPt.IsChecked == true) lang = "pt";
        else if (LangZh.IsChecked == true) lang = "zh";
        else if (LangJa.IsChecked == true) lang = "ja";
        else if (LangKo.IsChecked == true) lang = "ko";

        SettingsService.Instance.SelectedLanguage = lang;
    }

    // Rules Tab
    private void AddRule_Click(object sender, RoutedEventArgs e)
    {
        var rule = NewRuleTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(rule))
        {
            SettingsService.Instance.AddPromptRule(rule);
            NewRuleTextBox.Text = "";
            RefreshRulesList();
        }
    }

    private void DeleteRule_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is PromptRule rule)
        {
            var rules = SettingsService.Instance.PromptRules;
            var index = rules.FindIndex(r => r.Text == rule.Text);
            if (index >= 0)
            {
                SettingsService.Instance.RemovePromptRule(index);
                RefreshRulesList();
            }
        }
    }

    private void RuleToggle_Changed(object sender, RoutedEventArgs e)
    {
        // Rules are updated via binding, just save
        SettingsService.Instance.PromptRules = SettingsService.Instance.PromptRules;
    }

    private void RefreshRulesList()
    {
        RulesList.ItemsSource = null;
        RulesList.ItemsSource = SettingsService.Instance.PromptRules;
    }
}

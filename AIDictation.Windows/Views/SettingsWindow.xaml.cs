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
        ShowOverlayWhenIdleCheck.IsChecked = SettingsService.Instance.ShowOverlayWhenIdle;

        // Load overlay position combo
        OverlayPositionCombo.Items.Clear();
        OverlayPositionCombo.Items.Add("Top");
        OverlayPositionCombo.Items.Add("Bottom");
        var currentPosition = SettingsService.Instance.OverlayPosition;
        OverlayPositionCombo.SelectedItem = currentPosition;

        LaunchAtStartupCheck.IsChecked = SettingsService.Instance.LaunchAtStartup;
        IncludeScreenContextCheck.IsChecked = SettingsService.Instance.IncludeScreenContext;
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

        // Load languages (multi-select)
        UpdateLanguageButtons();

        // Check microphone permission status
        CheckMicrophonePermission();

        // Load dictionary, rules, and shortcuts
        RefreshDictionaryList();
        RefreshRulesList();
        RefreshShortcutsList();

        // Update Account UI
        UpdateAccountUI();
    }

    private void UpdateAccountUI()
    {
        var settings = SettingsService.Instance;
        var isAuthenticated = settings.IsAuthenticated;
        var isPro = settings.SubscriptionTier == SubscriptionTier.Pro;

        if (isAuthenticated)
        {
            // Show email and Sign Out button
            AccountStatusText.Text = settings.UserEmail;
            SignInButton.Visibility = Visibility.Collapsed;
            SignOutButton.Visibility = Visibility.Visible;

            // Show subscription status
            SubscriptionRow.Visibility = Visibility.Visible;
            SubscriptionText.Text = isPro ? "Pro" : "Free";

            // Show word usage only for Free tier
            if (!isPro)
            {
                WordUsageRow.Visibility = Visibility.Visible;
                WordUsageText.Text = $"{settings.MonthlyWordCount} of 2,000 words this month";
                UpgradeCard.Visibility = Visibility.Visible;
            }
            else
            {
                WordUsageRow.Visibility = Visibility.Collapsed;
                UpgradeCard.Visibility = Visibility.Collapsed;
            }
        }
        else
        {
            // Not authenticated - show Sign In button
            AccountStatusText.Text = "Sign in to track usage and unlock Pro features";
            SignInButton.Visibility = Visibility.Visible;
            SignOutButton.Visibility = Visibility.Collapsed;
            SubscriptionRow.Visibility = Visibility.Collapsed;
            WordUsageRow.Visibility = Visibility.Collapsed;
            UpgradeCard.Visibility = Visibility.Visible;
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
        DictionaryPanel.Visibility = DictionaryTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        RulesPanel.Visibility = RulesTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        ShortcutsPanel.Visibility = ShortcutsTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    // MARK: - General Tab

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

    private void ShowOverlayWhenIdle_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.ShowOverlayWhenIdle = ShowOverlayWhenIdleCheck.IsChecked == true;
    }

    private void OverlayPosition_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (OverlayPositionCombo.SelectedItem != null)
        {
            SettingsService.Instance.OverlayPosition = OverlayPositionCombo.SelectedItem.ToString() ?? "Top";
        }
    }

    private void IncludeScreenContext_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.IncludeScreenContext = IncludeScreenContextCheck.IsChecked == true;
    }

    private void AutoPaste_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.AutoPaste = AutoPasteCheck.IsChecked == true;
    }

    // MARK: - Account Tab

    private void SignIn_Click(object sender, RoutedEventArgs e)
    {
        // TODO: Open sign-in URL in browser
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://aidictation.com/login",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to open URL: {ex.Message}");
        }
    }

    private void SignOut_Click(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            "Are you sure you want to sign out?",
            "Sign Out",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (result == MessageBoxResult.Yes)
        {
            // Clear authentication data
            SettingsService.Instance.IsAuthenticated = false;
            SettingsService.Instance.UserEmail = string.Empty;
            SettingsService.Instance.SubscriptionTier = SubscriptionTier.Free;
            SettingsService.Instance.MonthlyWordCount = 0;

            // Update UI
            UpdateAccountUI();
        }
    }

    private void Upgrade_Click(object sender, RoutedEventArgs e)
    {
        // TODO: Open upgrade URL in browser
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://aidictation.com/upgrade",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to open URL: {ex.Message}");
        }
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

    // MARK: - Permissions Tab

    private void CheckMicrophonePermission()
    {
        try
        {
            // Try to enumerate audio devices - if we can get devices, permission is granted
            var deviceCount = NAudio.Wave.WaveInEvent.DeviceCount;
            var hasPermission = deviceCount > 0;

            if (hasPermission)
            {
                MicPermissionStatus.Visibility = Visibility.Visible;
                MicPermissionButton.Visibility = Visibility.Collapsed;
            }
            else
            {
                MicPermissionStatus.Visibility = Visibility.Collapsed;
                MicPermissionButton.Visibility = Visibility.Visible;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to check microphone permission: {ex.Message}");
            // On error, show button to allow user to fix
            MicPermissionStatus.Visibility = Visibility.Collapsed;
            MicPermissionButton.Visibility = Visibility.Visible;
        }
    }

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

    private void OpenScreenCaptureSettings_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "ms-settings:privacy-graphicsCaptureWithoutBorder",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to open screen capture settings: {ex.Message}");
        }
    }

    // MARK: - Audio Tab

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

    // MARK: - Language Tab

    private void LanguageToggle_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Primitives.ToggleButton button && button.Tag is string languageCode)
        {
            SettingsService.Instance.ToggleLanguage(languageCode);
            UpdateLanguageButtons();
        }
    }

    private void UpdateLanguageButtons()
    {
        LangAuto.IsChecked = SettingsService.Instance.IsLanguageSelected("auto");
        LangEn.IsChecked = SettingsService.Instance.IsLanguageSelected("en");
        LangRu.IsChecked = SettingsService.Instance.IsLanguageSelected("ru");
        LangDe.IsChecked = SettingsService.Instance.IsLanguageSelected("de");
        LangFr.IsChecked = SettingsService.Instance.IsLanguageSelected("fr");
        LangEs.IsChecked = SettingsService.Instance.IsLanguageSelected("es");
        LangIt.IsChecked = SettingsService.Instance.IsLanguageSelected("it");
        LangPt.IsChecked = SettingsService.Instance.IsLanguageSelected("pt");
        LangZh.IsChecked = SettingsService.Instance.IsLanguageSelected("zh");
        LangJa.IsChecked = SettingsService.Instance.IsLanguageSelected("ja");
        LangKo.IsChecked = SettingsService.Instance.IsLanguageSelected("ko");
    }

    // MARK: - Dictionary Tab

    private void AddDictEntry_Click(object sender, RoutedEventArgs e)
    {
        var trigger = DictTriggerTextBox.Text.Trim();
        var replacement = DictReplacementTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(trigger) && !string.IsNullOrEmpty(replacement))
        {
            SettingsService.Instance.AddDictionaryEntry(trigger, replacement);
            DictTriggerTextBox.Text = "";
            DictReplacementTextBox.Text = "";
            RefreshDictionaryList();
        }
    }

    private void DeleteDictEntry_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is DictionaryEntry entry)
        {
            var entries = SettingsService.Instance.DictionaryEntries;
            var index = entries.FindIndex(d => d.Trigger == entry.Trigger);
            if (index >= 0)
            {
                SettingsService.Instance.RemoveDictionaryEntry(index);
                RefreshDictionaryList();
            }
        }
    }

    private void RefreshDictionaryList()
    {
        DictionaryList.ItemsSource = null;
        DictionaryList.ItemsSource = SettingsService.Instance.DictionaryEntries;
    }

    // MARK: - Context Rules Tab

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

    // MARK: - Shortcuts Tab

    private void AddShortcut_Click(object sender, RoutedEventArgs e)
    {
        var trigger = ShortcutTriggerTextBox.Text.Trim();
        var expansion = ShortcutExpansionTextBox.Text.Trim();
        if (!string.IsNullOrEmpty(trigger) && !string.IsNullOrEmpty(expansion))
        {
            SettingsService.Instance.AddShortcut(trigger, expansion);
            ShortcutTriggerTextBox.Text = "";
            ShortcutExpansionTextBox.Text = "";
            RefreshShortcutsList();
        }
    }

    private void DeleteShortcut_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is VoiceShortcut shortcut)
        {
            var shortcuts = SettingsService.Instance.Shortcuts;
            var index = shortcuts.FindIndex(s => s.VoiceTrigger == shortcut.VoiceTrigger);
            if (index >= 0)
            {
                SettingsService.Instance.RemoveShortcut(index);
                RefreshShortcutsList();
            }
        }
    }

    private void RefreshShortcutsList()
    {
        ShortcutsList.ItemsSource = null;
        ShortcutsList.ItemsSource = SettingsService.Instance.Shortcuts;
    }
}

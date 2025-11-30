using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using AIDictation.Services;

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

        // Load language
        var lang = SettingsService.Instance.SelectedLanguage;
        switch (lang)
        {
            case "en": LangEn.IsChecked = true; break;
            case "ru": LangRu.IsChecked = true; break;
            case "de": LangDe.IsChecked = true; break;
            case "fr": LangFr.IsChecked = true; break;
            case "es": LangEs.IsChecked = true; break;
            default: LangAuto.IsChecked = true; break;
        }

        // Load auto paste
        AutoPasteCheck.IsChecked = SettingsService.Instance.AutoPaste;

        // Load rules
        RefreshRulesList();

        // Load hotkey
        CurrentHotkeyDisplay.Text = HotkeyService.Instance.GetHotkeyDisplayString();

        // Load API key (masked)
        var apiKey = SettingsService.Instance.ApiKey;
        if (!string.IsNullOrEmpty(apiKey))
        {
            ApiKeyTextBox.Text = apiKey;
        }
    }

    private void Tab_Checked(object sender, RoutedEventArgs e)
    {
        if (AudioPanel == null) return;

        AudioPanel.Visibility = AudioTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        RulesPanel.Visibility = RulesTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        HotkeyPanel.Visibility = HotkeyTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        ApiPanel.Visibility = ApiTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private void AudioDevice_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (AudioDeviceCombo.SelectedIndex >= 0)
        {
            SettingsService.Instance.SelectedAudioDevice = AudioDeviceCombo.SelectedIndex;
        }
    }

    private void Language_Checked(object sender, RoutedEventArgs e)
    {
        string lang = "auto";
        if (LangEn.IsChecked == true) lang = "en";
        else if (LangRu.IsChecked == true) lang = "ru";
        else if (LangDe.IsChecked == true) lang = "de";
        else if (LangFr.IsChecked == true) lang = "fr";
        else if (LangEs.IsChecked == true) lang = "es";

        SettingsService.Instance.SelectedLanguage = lang;
    }

    private void AutoPaste_Changed(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.AutoPaste = AutoPasteCheck.IsChecked == true;
    }

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

    private void RefreshRulesList()
    {
        RulesList.ItemsSource = null;
        RulesList.ItemsSource = SettingsService.Instance.PromptRules;
    }

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

        // Register the new hotkey
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

    private void ClearHotkey_Click(object sender, RoutedEventArgs e)
    {
        HotkeyService.Instance.UnregisterHotkey();
        SettingsService.Instance.HotkeyKeyCode = 0;
        SettingsService.Instance.HotkeyModifiers = 0;
        CurrentHotkeyDisplay.Text = "Not set";
    }

    private void ApiKey_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        // Could add validation here
    }

    private void SaveApiKey_Click(object sender, RoutedEventArgs e)
    {
        SettingsService.Instance.ApiKey = ApiKeyTextBox.Text.Trim();
        MessageBox.Show("API key saved successfully.", "Saved", MessageBoxButton.OK, MessageBoxImage.Information);
    }
}

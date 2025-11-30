using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Navigation;
using System.Windows.Threading;
using System.Windows.Controls.Primitives;
using AIDictation.Services;

namespace AIDictation.Views;

public partial class OnboardingWindow : Window
{
    private int _currentStep = 1;
    private bool _isCapturingHotkey = false;
    private Key _capturedKey = Key.None;
    private ModifierKeys _capturedModifiers = ModifierKeys.None;

    private readonly Brush _activeDotBrush;
    private readonly Brush _inactiveDotBrush;

    private DispatcherTimer? _permissionTimer;

    public OnboardingWindow()
    {
        InitializeComponent();

        _activeDotBrush = (Brush)FindResource("PrimaryBrush");
        _inactiveDotBrush = (Brush)FindResource("BorderBrush");

        PreviewKeyDown += OnPreviewKeyDown;
        PreviewKeyUp += OnPreviewKeyUp;
        Loaded += OnLoaded;
        Closed += OnClosed;

        UpdateUI();
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_currentStep == 1)
        {
            StartPermissionCheck();
        }
    }

    private void OnClosed(object? sender, EventArgs e)
    {
        StopPermissionCheck();
    }

    private void UpdateUI()
    {
        // Hide all steps
        Step1.Visibility = Visibility.Collapsed;
        Step2.Visibility = Visibility.Collapsed;
        Step3.Visibility = Visibility.Collapsed;
        Step4.Visibility = Visibility.Collapsed;
        Step5.Visibility = Visibility.Collapsed;

        // Hide all navigation buttons
        MicrophoneEnableButton.Visibility = Visibility.Collapsed;
        MicrophoneContinueButton.Visibility = Visibility.Collapsed;
        ScreenRecordingButtons.Visibility = Visibility.Collapsed;
        LanguageContinueButton.Visibility = Visibility.Collapsed;
        HotkeyContinueButton.Visibility = Visibility.Collapsed;
        CompleteButton.Visibility = Visibility.Collapsed;

        // Show current step and appropriate buttons
        switch (_currentStep)
        {
            case 1:
                Step1.Visibility = Visibility.Visible;
                StartPermissionCheck();
                UpdateMicrophoneButtons();
                break;
            case 2:
                Step2.Visibility = Visibility.Visible;
                ScreenRecordingButtons.Visibility = Visibility.Visible;
                StopPermissionCheck();
                break;
            case 3:
                Step3.Visibility = Visibility.Visible;
                LanguageContinueButton.Visibility = Visibility.Visible;
                UpdateLanguageButtons();
                break;
            case 4:
                Step4.Visibility = Visibility.Visible;
                HotkeyContinueButton.Visibility = Visibility.Visible;
                break;
            case 5:
                Step5.Visibility = Visibility.Visible;
                CompleteButton.Visibility = Visibility.Visible;
                break;
        }

        // Update dots
        Dot1.Fill = _currentStep >= 1 ? _activeDotBrush : _inactiveDotBrush;
        Dot2.Fill = _currentStep >= 2 ? _activeDotBrush : _inactiveDotBrush;
        Dot3.Fill = _currentStep >= 3 ? _activeDotBrush : _inactiveDotBrush;
        Dot4.Fill = _currentStep >= 4 ? _activeDotBrush : _inactiveDotBrush;
        Dot5.Fill = _currentStep >= 5 ? _activeDotBrush : _inactiveDotBrush;
    }

    private void UpdateMicrophoneButtons()
    {
        var hasDevices = NAudio.Wave.WaveInEvent.DeviceCount > 0;
        MicrophoneEnableButton.Visibility = hasDevices ? Visibility.Collapsed : Visibility.Visible;
        MicrophoneContinueButton.Visibility = hasDevices ? Visibility.Visible : Visibility.Collapsed;
        MicrophoneGrantedIndicator.Visibility = hasDevices ? Visibility.Visible : Visibility.Collapsed;
    }


    private void NextButton_Click(object sender, RoutedEventArgs e)
    {
        // Validate current step
        switch (_currentStep)
        {
            case 4:
                if (_capturedKey == Key.None)
                {
                    MessageBox.Show("Please set a hotkey to continue.", "Hotkey Required",
                        MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                // Register the hotkey
                HotkeyService.Instance.RegisterHotkey(_capturedKey, _capturedModifiers);
                break;
        }

        if (_currentStep < 5)
        {
            _currentStep++;
            UpdateUI();
        }
    }

    private void SkipButton_Click(object sender, RoutedEventArgs e)
    {
        // Skip current step (only available for Screen Recording step)
        if (_currentStep == 2)
        {
            _currentStep++;
            UpdateUI();
        }
    }

    private async void RequestMicrophonePermission_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            // Request microphone access by attempting to use it
            // This triggers the Windows permission prompt
            using var waveIn = new NAudio.Wave.WaveInEvent();
            waveIn.DeviceNumber = 0;
            waveIn.WaveFormat = new NAudio.Wave.WaveFormat(16000, 16, 1);

            // Start and immediately stop to trigger permission request
            waveIn.StartRecording();
            await System.Threading.Tasks.Task.Delay(100);
            waveIn.StopRecording();

            // Update UI after permission request
            UpdateMicrophoneButtons();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to request microphone: {ex.Message}");
            // If direct access fails, fall back to opening settings
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ms-settings:privacy-microphone",
                    UseShellExecute = true
                });
            }
            catch (Exception settingsEx)
            {
                Debug.WriteLine($"Failed to open settings: {settingsEx.Message}");
            }
        }
    }

    private void OpenScreenRecordingSettings_Click(object sender, RoutedEventArgs e)
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
            Debug.WriteLine($"Failed to open settings: {ex.Message}");
        }
    }

    private void HotkeyBox_Click(object sender, MouseButtonEventArgs e)
    {
        _isCapturingHotkey = true;
        HotkeyDisplay.Text = "Press your hotkey...";
        HotkeyDisplay.Foreground = (Brush)FindResource("PrimaryBrush");
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (!_isCapturingHotkey) return;

        // Ignore modifier-only keys
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

        UpdateHotkeyDisplay();

        _isCapturingHotkey = false;
        e.Handled = true;
    }

    private void OnPreviewKeyUp(object sender, KeyEventArgs e)
    {
        // Not used but kept for potential future use
    }

    private void UpdateHotkeyDisplay()
    {
        var parts = new System.Collections.Generic.List<string>();

        if (_capturedModifiers.HasFlag(ModifierKeys.Control))
            parts.Add("Ctrl");
        if (_capturedModifiers.HasFlag(ModifierKeys.Alt))
            parts.Add("Alt");
        if (_capturedModifiers.HasFlag(ModifierKeys.Shift))
            parts.Add("Shift");
        if (_capturedModifiers.HasFlag(ModifierKeys.Windows))
            parts.Add("Win");

        parts.Add(_capturedKey.ToString());

        HotkeyDisplay.Text = string.Join(" + ", parts);
        HotkeyDisplay.Foreground = (Brush)FindResource("TextPrimaryBrush");
    }

    private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = e.Uri.AbsoluteUri,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to open URL: {ex.Message}");
        }
        e.Handled = true;
    }

    private void StartPermissionCheck()
    {
        StopPermissionCheck();

        _permissionTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _permissionTimer.Tick += (s, e) => CheckMicrophonePermission();
        _permissionTimer.Start();

        CheckMicrophonePermission();
    }

    private void StopPermissionCheck()
    {
        if (_permissionTimer != null)
        {
            _permissionTimer.Stop();
            _permissionTimer = null;
        }
    }

    private void CheckMicrophonePermission()
    {
        try
        {
            UpdateMicrophoneButtons();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Failed to check microphone permission: {ex.Message}");
        }
    }

    private void UpdateLanguageButtons()
    {
        // Update all language button states based on current settings
        foreach (var child in LanguagePanel.Children)
        {
            if (child is ToggleButton button && button.Tag is string languageCode)
            {
                button.IsChecked = SettingsService.Instance.IsLanguageSelected(languageCode);
            }
        }
    }

    private void LanguageButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is ToggleButton button && button.Tag is string languageCode)
        {
            SettingsService.Instance.ToggleLanguage(languageCode);
            UpdateLanguageButtons();
        }
    }

    private void CompleteButton_Click(object sender, RoutedEventArgs e)
    {
        // Complete onboarding
        SettingsService.Instance.HasCompletedOnboarding = true;
        DialogResult = true;
        Close();
    }
}

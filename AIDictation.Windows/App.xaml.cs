using System;
using System.Drawing;
using System.Windows;
using AIDictation.Services;
using AIDictation.Views;
using Hardcodet.Wpf.TaskbarNotification;

namespace AIDictation;

public partial class App : Application
{
    private TaskbarIcon? _taskbarIcon;
    private HotkeyService? _hotkeyService;
    private AudioRecordingService? _audioService;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Initialize services
        _audioService = AudioRecordingService.Instance;
        _hotkeyService = HotkeyService.Instance;

        // Initialize system tray
        InitializeSystemTray();

        // Check if onboarding is needed
        if (!SettingsService.Instance.HasCompletedOnboarding)
        {
            ShowOnboarding();
        }
    }

    private void InitializeSystemTray()
    {
        // Load icon from embedded resource
        var iconStream = GetResourceStream(new Uri("pack://application:,,,/Assets/app.ico"))?.Stream;
        Icon? icon = null;
        if (iconStream != null)
        {
            icon = new Icon(iconStream);
        }

        _taskbarIcon = new TaskbarIcon
        {
            ToolTipText = "AIDictation",
            Icon = icon
        };

        _taskbarIcon.TrayMouseDoubleClick += (s, e) => ShowMainWindow();

        // Create context menu
        var contextMenu = new System.Windows.Controls.ContextMenu();

        var showItem = new System.Windows.Controls.MenuItem { Header = "Show" };
        showItem.Click += (s, e) => ShowMainWindow();
        contextMenu.Items.Add(showItem);

        var settingsItem = new System.Windows.Controls.MenuItem { Header = "Settings" };
        settingsItem.Click += (s, e) => ShowSettings();
        contextMenu.Items.Add(settingsItem);

        var historyItem = new System.Windows.Controls.MenuItem { Header = "History" };
        historyItem.Click += (s, e) => ShowHistory();
        contextMenu.Items.Add(historyItem);

        contextMenu.Items.Add(new System.Windows.Controls.Separator());

        var quitItem = new System.Windows.Controls.MenuItem { Header = "Quit" };
        quitItem.Click += (s, e) => Shutdown();
        contextMenu.Items.Add(quitItem);

        _taskbarIcon.ContextMenu = contextMenu;
    }

    private void ShowMainWindow()
    {
        if (MainWindow == null)
        {
            MainWindow = new MainWindow();
        }
        MainWindow.Show();
        MainWindow.Activate();
    }

    private void ShowOnboarding()
    {
        var onboarding = new OnboardingWindow();
        onboarding.ShowDialog();
    }

    private void ShowSettings()
    {
        var settings = new SettingsWindow();
        settings.ShowDialog();
    }

    private void ShowHistory()
    {
        var history = new HistoryWindow();
        history.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _taskbarIcon?.Dispose();
        _hotkeyService?.Dispose();
        _audioService?.Dispose();
        base.OnExit(e);
    }
}

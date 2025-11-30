using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using AIDictation.Services;

namespace AIDictation.Views;

public partial class MainWindow : Window
{
    private readonly AudioRecordingService _audioService;
    private readonly TranscriptionService _transcriptionService;
    private readonly HotkeyService _hotkeyService;
    private readonly ClipboardService _clipboardService;
    private readonly HistoryService _historyService;

    private string? _lastTranscription;
    private readonly Random _random = new();

    public MainWindow()
    {
        InitializeComponent();

        _audioService = AudioRecordingService.Instance;
        _transcriptionService = TranscriptionService.Instance;
        _hotkeyService = HotkeyService.Instance;
        _clipboardService = ClipboardService.Instance;
        _historyService = HistoryService.Instance;

        // Subscribe to events
        _audioService.StateChanged += OnRecordingStateChanged;
        _audioService.AudioLevelChanged += OnAudioLevelChanged;
        _audioService.RecordingCompleted += OnRecordingCompleted;
        _hotkeyService.HotkeyPressed += OnHotkeyPressed;

        // Update hotkey hint
        UpdateHotkeyHint();
    }

    private void UpdateHotkeyHint()
    {
        var hotkeyText = _hotkeyService.GetHotkeyDisplayString();
        HotkeyHint.Text = $"Press {hotkeyText} to record";
    }

    private void OnHotkeyPressed(object? sender, EventArgs e)
    {
        Dispatcher.Invoke(() =>
        {
            if (_audioService.CurrentState == RecordingState.Idle)
            {
                _audioService.StartRecording();
            }
            else if (_audioService.CurrentState == RecordingState.Recording)
            {
                _audioService.StopRecording();
            }
        });
    }

    private void OnRecordingStateChanged(object? sender, RecordingState state)
    {
        Dispatcher.Invoke(() =>
        {
            // Hide all views
            IdleView.Visibility = Visibility.Collapsed;
            RecordingView.Visibility = Visibility.Collapsed;
            ProcessingView.Visibility = Visibility.Collapsed;
            ResultView.Visibility = Visibility.Collapsed;
            ErrorView.Visibility = Visibility.Collapsed;
            CopyButton.Visibility = Visibility.Collapsed;

            switch (state)
            {
                case RecordingState.Idle:
                    IdleView.Visibility = Visibility.Visible;
                    HotkeyHint.Text = $"Press {_hotkeyService.GetHotkeyDisplayString()} to record";
                    break;

                case RecordingState.Recording:
                    RecordingView.Visibility = Visibility.Visible;
                    HotkeyHint.Text = $"Release {_hotkeyService.GetHotkeyDisplayString()} to stop";
                    break;

                case RecordingState.Processing:
                    ProcessingView.Visibility = Visibility.Visible;
                    HotkeyHint.Text = "Transcribing...";
                    break;
            }
        });
    }

    private void OnAudioLevelChanged(object? sender, float level)
    {
        Dispatcher.Invoke(() =>
        {
            DrawWaveform(level);
        });
    }

    private void DrawWaveform(float level)
    {
        WaveformCanvas.Children.Clear();

        const int barCount = 30;
        const double barWidth = 6;
        const double barSpacing = 4;
        const double maxHeight = 50;

        for (int i = 0; i < barCount; i++)
        {
            // Create varying heights based on audio level
            var variation = (float)(_random.NextDouble() * 0.5 + 0.5);
            var height = Math.Max(4, level * maxHeight * variation);

            var rect = new Rectangle
            {
                Width = barWidth,
                Height = height,
                Fill = new SolidColorBrush(Color.FromRgb(0x00, 0x7B, 0xFF)),
                RadiusX = 2,
                RadiusY = 2
            };

            Canvas.SetLeft(rect, i * (barWidth + barSpacing));
            Canvas.SetTop(rect, (maxHeight - height) / 2 + 5);

            WaveformCanvas.Children.Add(rect);
        }
    }

    private async void OnRecordingCompleted(object? sender, string audioFilePath)
    {
        var result = await _transcriptionService.TranscribeAsync(audioFilePath);

        Dispatcher.Invoke(async () =>
        {
            if (result.Success && !string.IsNullOrEmpty(result.Text))
            {
                _lastTranscription = result.Text;
                TranscriptionTextBox.Text = result.Text;
                ResultView.Visibility = Visibility.Visible;
                CopyButton.Visibility = Visibility.Visible;

                // Add to history
                _historyService.AddEntry(new RecordingEntry
                {
                    Transcription = result.Text,
                    AudioFilePath = audioFilePath,
                    HasError = false
                });

                // Auto copy and paste
                await _clipboardService.CopyAndPaste(result.Text);

                HotkeyHint.Text = $"Press {_hotkeyService.GetHotkeyDisplayString()} to record";
            }
            else
            {
                ErrorText.Text = result.Error ?? "Unknown error occurred";
                ErrorView.Visibility = Visibility.Visible;

                // Add error to history
                _historyService.AddEntry(new RecordingEntry
                {
                    AudioFilePath = audioFilePath,
                    HasError = true,
                    ErrorMessage = result.Error
                });
            }

            _audioService.SetIdle();
        });
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrEmpty(_lastTranscription))
        {
            _clipboardService.CopyToClipboard(_lastTranscription);
        }
    }

    private void RetryButton_Click(object sender, RoutedEventArgs e)
    {
        _audioService.SetIdle();
    }

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            // Double click - could toggle always on top
        }
        else
        {
            DragMove();
        }
    }

    private void MinimizeButton_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
    }

    protected override void OnClosed(EventArgs e)
    {
        _audioService.StateChanged -= OnRecordingStateChanged;
        _audioService.AudioLevelChanged -= OnAudioLevelChanged;
        _audioService.RecordingCompleted -= OnRecordingCompleted;
        _hotkeyService.HotkeyPressed -= OnHotkeyPressed;

        base.OnClosed(e);
    }
}

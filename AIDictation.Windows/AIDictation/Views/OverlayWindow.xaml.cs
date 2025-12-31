using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;
using AIDictation.Models;
using AIDictation.Services;

namespace AIDictation.Views;

/// <summary>
/// Compact floating overlay window for recording visualization.
/// Shows recording animation, processing spinner, or result preview.
/// </summary>
public partial class OverlayWindow : Window
{
    // MARK: - Constants
    
    private static class Constants
    {
        public const int WaveformBarCount = 32;
        public const double WaveformBarWidth = 4;
        public const double WaveformBarGap = 2;
        public const double WaveformMinHeight = 2;
        public const double WaveformMaxHeight = 28;
        public const double ResultDisplayDuration = 3.0; // seconds
        public const double ErrorDisplayDuration = 4.0; // seconds
    }
    
    // MARK: - Private Properties
    
    private readonly AppState _appState;
    private readonly DispatcherTimer _waveformTimer;
    private readonly DispatcherTimer _autoHideTimer;
    private readonly Rectangle[] _waveformBars;
    private readonly Random _random = new();
    private readonly double[] _waveformValues;
    private OverlayPosition _position = OverlayPosition.Bottom;
    private bool _hideWhenIdle = false;
    
    // MARK: - Initialization
    
    public OverlayWindow()
    {
        InitializeComponent();
        
        _appState = AppState.Shared;
        _waveformValues = new double[Constants.WaveformBarCount];
        _waveformBars = new Rectangle[Constants.WaveformBarCount];
        
        // Initialize waveform bars
        InitializeWaveform();
        
        // Setup timers
        _waveformTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(50)
        };
        _waveformTimer.Tick += WaveformTimer_Tick;
        
        _autoHideTimer = new DispatcherTimer();
        _autoHideTimer.Tick += AutoHideTimer_Tick;
        
        // Subscribe to state changes
        _appState.StateChanged += AppState_StateChanged;
        _appState.AudioLevelUpdated += AppState_AudioLevelUpdated;
        _appState.PropertyChanged += AppState_PropertyChanged;
        
        // Initialize position
        Loaded += OverlayWindow_Loaded;
    }
    
    // MARK: - Public API
    
    /// <summary>
    /// Updates the overlay position setting
    /// </summary>
    public void SetPosition(OverlayPosition position)
    {
        _position = position;
        UpdateWindowPosition();
    }
    
    /// <summary>
    /// Sets whether to hide the overlay when idle
    /// </summary>
    public void SetHideWhenIdle(bool hide)
    {
        _hideWhenIdle = hide;
        UpdateVisibilityForState(_appState.CurrentState);
    }
    
    /// <summary>
    /// Shows the overlay with fade-in animation
    /// </summary>
    public void ShowOverlay()
    {
        if (!IsVisible)
        {
            Show();
            var fadeIn = (Storyboard)FindResource("FadeInAnimation");
            fadeIn.Begin(this);
        }
    }
    
    /// <summary>
    /// Hides the overlay with fade-out animation
    /// </summary>
    public void HideOverlay()
    {
        if (IsVisible)
        {
            var fadeOut = (Storyboard)FindResource("FadeOutAnimation");
            fadeOut.Completed += (s, e) => Hide();
            fadeOut.Begin(this);
        }
    }
    
    // MARK: - Private Methods
    
    private void InitializeWaveform()
    {
        var accentBrush = new SolidColorBrush(Color.FromRgb(0, 120, 212));
        
        for (int i = 0; i < Constants.WaveformBarCount; i++)
        {
            var bar = new Rectangle
            {
                Width = Constants.WaveformBarWidth,
                Height = Constants.WaveformMinHeight,
                Fill = accentBrush,
                RadiusX = 2,
                RadiusY = 2
            };
            
            _waveformBars[i] = bar;
            _waveformValues[i] = Constants.WaveformMinHeight;
            
            WaveformCanvas.Children.Add(bar);
        }
        
        // Position bars after canvas is loaded
        WaveformCanvas.Loaded += (s, e) => PositionWaveformBars();
    }
    
    private void PositionWaveformBars()
    {
        double totalWidth = Constants.WaveformBarCount * (Constants.WaveformBarWidth + Constants.WaveformBarGap) - Constants.WaveformBarGap;
        double startX = (WaveformCanvas.ActualWidth - totalWidth) / 2;
        double centerY = WaveformCanvas.ActualHeight / 2;
        
        for (int i = 0; i < Constants.WaveformBarCount; i++)
        {
            var bar = _waveformBars[i];
            System.Windows.Controls.Canvas.SetLeft(bar, startX + i * (Constants.WaveformBarWidth + Constants.WaveformBarGap));
            System.Windows.Controls.Canvas.SetTop(bar, centerY - bar.Height / 2);
        }
    }
    
    private void UpdateWaveform(float audioLevel)
    {
        double canvasHeight = WaveformCanvas.ActualHeight;
        if (canvasHeight <= 0) return;
        
        double centerY = canvasHeight / 2;
        
        // Shift values left
        for (int i = 0; i < Constants.WaveformBarCount - 1; i++)
        {
            _waveformValues[i] = _waveformValues[i + 1];
        }
        
        // Add new value with some randomness for visual interest
        double targetHeight = Constants.WaveformMinHeight + 
            (Constants.WaveformMaxHeight - Constants.WaveformMinHeight) * audioLevel;
        targetHeight *= (0.8 + _random.NextDouble() * 0.4); // Add 80-120% variance
        targetHeight = Math.Clamp(targetHeight, Constants.WaveformMinHeight, Constants.WaveformMaxHeight);
        _waveformValues[Constants.WaveformBarCount - 1] = targetHeight;
        
        // Update bars
        for (int i = 0; i < Constants.WaveformBarCount; i++)
        {
            var bar = _waveformBars[i];
            bar.Height = _waveformValues[i];
            System.Windows.Controls.Canvas.SetTop(bar, centerY - bar.Height / 2);
        }
    }
    
    private void UpdateWindowPosition()
    {
        var workArea = SystemParameters.WorkArea;
        
        Left = (workArea.Width - Width) / 2 + workArea.Left;
        
        if (_position == OverlayPosition.Top)
        {
            Top = workArea.Top + 20;
        }
        else
        {
            Top = workArea.Bottom - Height - 20;
        }
    }
    
    private void UpdateVisibilityForState(AppState.State state)
    {
        // Hide all panels first
        IdlePanel.Visibility = Visibility.Collapsed;
        RecordingPanel.Visibility = Visibility.Collapsed;
        ProcessingPanel.Visibility = Visibility.Collapsed;
        ResultPanel.Visibility = Visibility.Collapsed;
        ErrorPanel.Visibility = Visibility.Collapsed;
        
        // Stop animations
        _waveformTimer.Stop();
        _autoHideTimer.Stop();
        
        var recordingPulse = (Storyboard)FindResource("RecordingPulseAnimation");
        var spinnerAnim = (Storyboard)FindResource("SpinnerAnimation");
        
        recordingPulse.Stop(this);
        spinnerAnim.Stop(this);
        
        switch (state)
        {
            case AppState.State.Idle:
                if (_hideWhenIdle)
                {
                    HideOverlay();
                }
                else
                {
                    IdlePanel.Visibility = Visibility.Visible;
                    ShowOverlay();
                }
                break;
                
            case AppState.State.Recording:
                RecordingPanel.Visibility = Visibility.Visible;
                recordingPulse.Begin(this, true);
                _waveformTimer.Start();
                ShowOverlay();
                break;
                
            case AppState.State.Processing:
                ProcessingPanel.Visibility = Visibility.Visible;
                spinnerAnim.Begin(this, true);
                ShowOverlay();
                break;
                
            case AppState.State.Result:
                ResultPanel.Visibility = Visibility.Visible;
                ResultPreviewText.Text = TruncateText(_appState.TranscriptionText, 40);
                ShowOverlay();
                
                // Auto-hide after delay
                _autoHideTimer.Interval = TimeSpan.FromSeconds(Constants.ResultDisplayDuration);
                _autoHideTimer.Start();
                break;
                
            case AppState.State.Error:
                ErrorPanel.Visibility = Visibility.Visible;
                ErrorText.Text = TruncateText(_appState.ErrorMessage, 35);
                ShowOverlay();
                
                // Auto-hide after delay
                _autoHideTimer.Interval = TimeSpan.FromSeconds(Constants.ErrorDisplayDuration);
                _autoHideTimer.Start();
                break;
        }
    }
    
    private string TruncateText(string text, int maxLength)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        
        // Replace newlines with spaces
        text = text.Replace("\r\n", " ").Replace("\n", " ").Trim();
        
        if (text.Length <= maxLength) return text;
        return text[..(maxLength - 1)] + "…";
    }
    
    private string FormatDuration(TimeSpan duration)
    {
        if (duration.TotalHours >= 1)
        {
            return duration.ToString(@"h\:mm\:ss");
        }
        return duration.ToString(@"m\:ss");
    }
    
    // MARK: - Event Handlers
    
    private void OverlayWindow_Loaded(object sender, RoutedEventArgs e)
    {
        UpdateWindowPosition();
        UpdateVisibilityForState(_appState.CurrentState);
    }
    
    private void AppState_StateChanged(object? sender, AppState.StateChangedEventArgs e)
    {
        Dispatcher.Invoke(() => UpdateVisibilityForState(e.NewState));
    }
    
    private void AppState_AudioLevelUpdated(object? sender, float level)
    {
        Dispatcher.Invoke(() =>
        {
            if (_appState.CurrentState == AppState.State.Recording)
            {
                UpdateWaveform(level);
            }
        });
    }
    
    private void AppState_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(AppState.RecordingDuration))
        {
            Dispatcher.Invoke(() =>
            {
                DurationText.Text = FormatDuration(_appState.RecordingDuration);
            });
        }
    }
    
    private void WaveformTimer_Tick(object? sender, EventArgs e)
    {
        // Simulate waveform movement when no real audio level updates
        if (_appState.CurrentState == AppState.State.Recording)
        {
            UpdateWaveform(_appState.CurrentAudioLevel);
        }
    }
    
    private void AutoHideTimer_Tick(object? sender, EventArgs e)
    {
        _autoHideTimer.Stop();
        _appState.Reset();
    }
    
    // MARK: - Cleanup
    
    protected override void OnClosed(EventArgs e)
    {
        _appState.StateChanged -= AppState_StateChanged;
        _appState.AudioLevelUpdated -= AppState_AudioLevelUpdated;
        _appState.PropertyChanged -= AppState_PropertyChanged;
        _waveformTimer.Stop();
        _autoHideTimer.Stop();
        base.OnClosed(e);
    }
}

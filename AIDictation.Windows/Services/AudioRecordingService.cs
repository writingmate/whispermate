using System;
using System.IO;
using System.Threading.Tasks;
using NAudio.Wave;

namespace AIDictation.Services;

public enum RecordingState
{
    Idle,
    Recording,
    Processing
}

public class AudioRecordingService : IDisposable
{
    private static readonly Lazy<AudioRecordingService> _instance = new(() => new AudioRecordingService());
    public static AudioRecordingService Instance => _instance.Value;

    private WaveInEvent? _waveIn;
    private WaveFileWriter? _waveWriter;
    private string? _currentFilePath;
    private readonly string _recordingsFolder;

    public event EventHandler<RecordingState>? StateChanged;
    public event EventHandler<float>? AudioLevelChanged;
    public event EventHandler<string>? RecordingCompleted;

    public RecordingState CurrentState { get; private set; } = RecordingState.Idle;

    private AudioRecordingService()
    {
        _recordingsFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "AIDictation",
            "Recordings"
        );
        Directory.CreateDirectory(_recordingsFolder);
    }

    public void StartRecording()
    {
        if (CurrentState != RecordingState.Idle) return;

        try
        {
            var deviceIndex = SettingsService.Instance.SelectedAudioDevice;
            _waveIn = new WaveInEvent
            {
                DeviceNumber = deviceIndex,
                WaveFormat = new WaveFormat(16000, 16, 1) // 16kHz, 16-bit, mono - optimal for Whisper
            };

            _currentFilePath = Path.Combine(_recordingsFolder, $"recording_{DateTime.Now:yyyyMMdd_HHmmss}.wav");
            _waveWriter = new WaveFileWriter(_currentFilePath, _waveIn.WaveFormat);

            _waveIn.DataAvailable += OnDataAvailable;
            _waveIn.RecordingStopped += OnRecordingStopped;

            _waveIn.StartRecording();
            SetState(RecordingState.Recording);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to start recording: {ex.Message}");
            Cleanup();
        }
    }

    public void StopRecording()
    {
        if (CurrentState != RecordingState.Recording) return;

        _waveIn?.StopRecording();
        SetState(RecordingState.Processing);
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        _waveWriter?.Write(e.Buffer, 0, e.BytesRecorded);

        // Calculate audio level for visualization
        float max = 0;
        for (int i = 0; i < e.BytesRecorded; i += 2)
        {
            short sample = BitConverter.ToInt16(e.Buffer, i);
            float sampleLevel = Math.Abs(sample / 32768f);
            if (sampleLevel > max) max = sampleLevel;
        }
        AudioLevelChanged?.Invoke(this, max);
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs e)
    {
        var filePath = _currentFilePath;
        Cleanup();

        if (!string.IsNullOrEmpty(filePath) && File.Exists(filePath))
        {
            RecordingCompleted?.Invoke(this, filePath);
        }
    }

    private void Cleanup()
    {
        _waveWriter?.Dispose();
        _waveWriter = null;

        if (_waveIn != null)
        {
            _waveIn.DataAvailable -= OnDataAvailable;
            _waveIn.RecordingStopped -= OnRecordingStopped;
            _waveIn.Dispose();
            _waveIn = null;
        }
    }

    private void SetState(RecordingState state)
    {
        CurrentState = state;
        StateChanged?.Invoke(this, state);
    }

    public void SetIdle()
    {
        SetState(RecordingState.Idle);
    }

    public static WaveInCapabilities[] GetAudioDevices()
    {
        var devices = new WaveInCapabilities[WaveInEvent.DeviceCount];
        for (int i = 0; i < WaveInEvent.DeviceCount; i++)
        {
            devices[i] = WaveInEvent.GetCapabilities(i);
        }
        return devices;
    }

    public void Dispose()
    {
        Cleanup();
    }
}

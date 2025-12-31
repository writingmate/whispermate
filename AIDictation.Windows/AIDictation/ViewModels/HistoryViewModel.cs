using System;
using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using AIDictation.Models;
using AIDictation.Services;

namespace AIDictation.ViewModels;

/// <summary>
/// ViewModel for the history window displaying all past recordings.
/// Provides search, copy, and delete functionality.
/// </summary>
public partial class HistoryViewModel : ObservableObject
{
    // MARK: - Constants

    private static class Constants
    {
        public const int PreviewMaxLength = 100;
    }

    // MARK: - Published Properties

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private ObservableCollection<RecordingItemViewModel> _filteredRecordings = new();

    [ObservableProperty]
    private bool _isEmpty = true;

    [ObservableProperty]
    private bool _hasSearchResults = true;

    // MARK: - Private Properties

    private readonly HistoryService _historyService;

    // MARK: - Initialization

    public HistoryViewModel()
    {
        _historyService = HistoryService.Instance;
        _historyService.HistoryChanged += OnHistoryChanged;
        
        LoadRecordings();
    }

    // MARK: - Commands

    [RelayCommand]
    private void Search()
    {
        ApplyFilter();
    }

    [RelayCommand]
    private void CopyToClipboard(RecordingItemViewModel? item)
    {
        if (item?.Transcription == null) return;
        
        try
        {
            System.Windows.Clipboard.SetText(item.Transcription);
        }
        catch
        {
            // Silently fail
        }
    }

    [RelayCommand]
    private void Delete(RecordingItemViewModel? item)
    {
        if (item == null) return;
        
        _historyService.Delete(item.Id);
    }

    [RelayCommand]
    private void ClearAll()
    {
        _historyService.Clear();
    }

    // MARK: - Public API

    public void Refresh()
    {
        LoadRecordings();
    }

    // MARK: - Private Methods

    private void LoadRecordings()
    {
        _historyService.Load();
        ApplyFilter();
    }

    private void ApplyFilter()
    {
        var recordings = string.IsNullOrWhiteSpace(SearchQuery)
            ? _historyService.Recordings.ToList()
            : _historyService.Search(SearchQuery).ToList();

        FilteredRecordings.Clear();
        foreach (var recording in recordings)
        {
            FilteredRecordings.Add(new RecordingItemViewModel(recording));
        }

        IsEmpty = _historyService.Recordings.Count == 0;
        HasSearchResults = FilteredRecordings.Count > 0 || string.IsNullOrWhiteSpace(SearchQuery);
    }

    private void OnHistoryChanged(object? sender, EventArgs e)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(ApplyFilter);
    }

    partial void OnSearchQueryChanged(string value)
    {
        ApplyFilter();
    }
}

/// <summary>
/// ViewModel wrapper for a single recording item in the history list.
/// </summary>
public partial class RecordingItemViewModel : ObservableObject
{
    // MARK: - Constants

    private static class Constants
    {
        public const int PreviewMaxLength = 100;
    }

    // MARK: - Properties

    public Guid Id { get; }
    public DateTime Timestamp { get; }
    public string? Transcription { get; }
    public double? Duration { get; }
    public TranscriptionStatus Status { get; }

    public string FormattedDate => Timestamp.ToString("MM/dd/yyyy h:mm tt");

    public string FormattedDuration
    {
        get
        {
            if (Duration == null) return "0s";
            var totalSeconds = Duration.Value;
            if (totalSeconds < 60)
                return $"{totalSeconds:F1}s";
            var minutes = (int)(totalSeconds / 60);
            var seconds = totalSeconds % 60;
            return $"{minutes}:{seconds:00.0}";
        }
    }

    public string TranscriptionPreview
    {
        get
        {
            if (string.IsNullOrEmpty(Transcription))
                return Status == TranscriptionStatus.Failed ? "[Transcription failed]" : "[No transcription]";

            if (Transcription.Length <= Constants.PreviewMaxLength)
                return Transcription;

            return Transcription[..Constants.PreviewMaxLength] + "...";
        }
    }

    public bool IsSuccessful => Status == TranscriptionStatus.Success;

    // MARK: - Initialization

    public RecordingItemViewModel(Recording recording)
    {
        Id = recording.Id;
        Timestamp = recording.Timestamp;
        Transcription = recording.Transcription;
        Duration = recording.Duration;
        Status = recording.Status;
    }
}

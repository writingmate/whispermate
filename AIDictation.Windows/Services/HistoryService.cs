using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace AIDictation.Services;

public class RecordingEntry
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public DateTime Timestamp { get; set; } = DateTime.Now;
    public string? Transcription { get; set; }
    public string? AudioFilePath { get; set; }
    public double DurationSeconds { get; set; }
    public bool HasError { get; set; }
    public string? ErrorMessage { get; set; }
}

public class HistoryService
{
    private static readonly Lazy<HistoryService> _instance = new(() => new HistoryService());
    public static HistoryService Instance => _instance.Value;

    private readonly string _historyPath;
    private List<RecordingEntry> _entries;

    public event EventHandler? HistoryChanged;

    public IReadOnlyList<RecordingEntry> Entries => _entries.AsReadOnly();

    private HistoryService()
    {
        var appDataFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "AIDictation"
        );
        Directory.CreateDirectory(appDataFolder);

        _historyPath = Path.Combine(appDataFolder, "history.json");
        _entries = LoadHistory();
    }

    public void AddEntry(RecordingEntry entry)
    {
        _entries.Insert(0, entry);

        // Keep only last 100 entries
        if (_entries.Count > 100)
        {
            var toRemove = _entries.Skip(100).ToList();
            foreach (var old in toRemove)
            {
                // Delete old audio files
                if (!string.IsNullOrEmpty(old.AudioFilePath) && File.Exists(old.AudioFilePath))
                {
                    try { File.Delete(old.AudioFilePath); } catch { }
                }
                _entries.Remove(old);
            }
        }

        Save();
        HistoryChanged?.Invoke(this, EventArgs.Empty);
    }

    public void DeleteEntry(string id)
    {
        var entry = _entries.FirstOrDefault(e => e.Id == id);
        if (entry != null)
        {
            // Delete audio file
            if (!string.IsNullOrEmpty(entry.AudioFilePath) && File.Exists(entry.AudioFilePath))
            {
                try { File.Delete(entry.AudioFilePath); } catch { }
            }

            _entries.Remove(entry);
            Save();
            HistoryChanged?.Invoke(this, EventArgs.Empty);
        }
    }

    public void ClearHistory()
    {
        foreach (var entry in _entries)
        {
            if (!string.IsNullOrEmpty(entry.AudioFilePath) && File.Exists(entry.AudioFilePath))
            {
                try { File.Delete(entry.AudioFilePath); } catch { }
            }
        }

        _entries.Clear();
        Save();
        HistoryChanged?.Invoke(this, EventArgs.Empty);
    }

    public List<RecordingEntry> Search(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return _entries.ToList();

        return _entries
            .Where(e => e.Transcription?.Contains(query, StringComparison.OrdinalIgnoreCase) == true)
            .ToList();
    }

    private List<RecordingEntry> LoadHistory()
    {
        try
        {
            if (File.Exists(_historyPath))
            {
                var json = File.ReadAllText(_historyPath);
                return JsonSerializer.Deserialize<List<RecordingEntry>>(json) ?? new List<RecordingEntry>();
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to load history: {ex.Message}");
        }
        return new List<RecordingEntry>();
    }

    private void Save()
    {
        try
        {
            var json = JsonSerializer.Serialize(_entries, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            File.WriteAllText(_historyPath, json);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to save history: {ex.Message}");
        }
    }
}

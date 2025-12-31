using System;
using Newtonsoft.Json;

namespace AIDictation.Models;

public enum TranscriptionStatus
{
    Success,
    Failed,
    Retrying
}

public class Recording
{
    [JsonProperty("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [JsonProperty("timestamp")]
    public DateTime Timestamp { get; set; } = DateTime.Now;

    [JsonProperty("audioFilePath")]
    public string AudioFilePath { get; set; } = string.Empty;

    [JsonProperty("transcription")]
    public string? Transcription { get; set; }

    [JsonProperty("status")]
    public TranscriptionStatus Status { get; set; } = TranscriptionStatus.Success;

    [JsonProperty("errorMessage")]
    public string? ErrorMessage { get; set; }

    [JsonProperty("retryCount")]
    public int RetryCount { get; set; }

    [JsonProperty("duration")]
    public double? Duration { get; set; }

    [JsonProperty("wordCount")]
    public int? WordCount { get; set; }

    [JsonIgnore]
    public string FormattedDate => Timestamp.ToString("g");

    [JsonIgnore]
    public string? FormattedDuration
    {
        get
        {
            if (Duration == null) return null;
            var minutes = (int)(Duration.Value / 60);
            var seconds = (int)(Duration.Value % 60);
            return minutes > 0 ? $"{minutes}:{seconds:D2}" : $"{seconds}s";
        }
    }

    [JsonIgnore]
    public bool IsSuccessful => Status == TranscriptionStatus.Success;

    [JsonIgnore]
    public bool IsFailed => Status == TranscriptionStatus.Failed;
}

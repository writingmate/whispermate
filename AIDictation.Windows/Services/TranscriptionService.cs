using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

namespace AIDictation.Services;

public class TranscriptionResult
{
    public bool Success { get; set; }
    public string? Text { get; set; }
    public string? Error { get; set; }
}

public class TranscriptionService : IDisposable
{
    private static readonly Lazy<TranscriptionService> _instance = new(() => new TranscriptionService());
    public static TranscriptionService Instance => _instance.Value;

    private readonly HttpClient _httpClient;
    private const string OpenAIApiUrl = "https://api.openai.com/v1/audio/transcriptions";

    private TranscriptionService()
    {
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromMinutes(2)
        };
    }

    public async Task<TranscriptionResult> TranscribeAsync(string audioFilePath)
    {
        try
        {
            var apiKey = SettingsService.Instance.ApiKey;
            if (string.IsNullOrEmpty(apiKey))
            {
                return new TranscriptionResult
                {
                    Success = false,
                    Error = "API key not configured. Please add your OpenAI API key in Settings."
                };
            }

            if (!File.Exists(audioFilePath))
            {
                return new TranscriptionResult
                {
                    Success = false,
                    Error = "Audio file not found."
                };
            }

            using var content = new MultipartFormDataContent();

            // Add audio file
            var audioBytes = await File.ReadAllBytesAsync(audioFilePath);
            var audioContent = new ByteArrayContent(audioBytes);
            audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
            content.Add(audioContent, "file", Path.GetFileName(audioFilePath));

            // Add model
            content.Add(new StringContent("whisper-1"), "model");

            // Add language if specified (supports multi-select, comma-separated)
            var language = SettingsService.Instance.GetApiLanguageCode();
            if (!string.IsNullOrEmpty(language) && language != "auto")
            {
                content.Add(new StringContent(language), "language");
            }

            // Add prompt rules if any
            var promptRules = SettingsService.Instance.GetPromptRules();
            if (!string.IsNullOrEmpty(promptRules))
            {
                content.Add(new StringContent(promptRules), "prompt");
            }

            // Set authorization
            _httpClient.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", apiKey);

            var response = await _httpClient.PostAsync(OpenAIApiUrl, content);

            if (response.IsSuccessStatusCode)
            {
                var jsonResponse = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<OpenAIResponse>(jsonResponse);

                return new TranscriptionResult
                {
                    Success = true,
                    Text = result?.Text ?? string.Empty
                };
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                return new TranscriptionResult
                {
                    Success = false,
                    Error = $"API error: {response.StatusCode} - {error}"
                };
            }
        }
        catch (TaskCanceledException)
        {
            return new TranscriptionResult
            {
                Success = false,
                Error = "Request timed out. Please try again."
            };
        }
        catch (Exception ex)
        {
            return new TranscriptionResult
            {
                Success = false,
                Error = $"Transcription failed: {ex.Message}"
            };
        }
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    private class OpenAIResponse
    {
        public string? Text { get; set; }
    }
}

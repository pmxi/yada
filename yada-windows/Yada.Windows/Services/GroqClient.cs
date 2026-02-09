using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Yada.Windows.Services;

public sealed class GroqClient : IDisposable
{
    private const string TranscribeUrl = "https://api.groq.com/openai/v1/audio/transcriptions";
    private const string RewriteUrl = "https://api.groq.com/openai/v1/chat/completions";

    private const string TranscribeModel = "whisper-large-v3";
    private const string RewriteModel = "moonshotai/kimi-k2-instruct";

    private readonly HttpClient _httpClient;

    public GroqClient(HttpClient? httpClient = null)
    {
        _httpClient = httpClient ?? new HttpClient();
    }

    public async Task<string> TranscribeAsync(byte[] wavData, string apiKey, CancellationToken cancellationToken)
    {
        ValidateApiKey(apiKey);

        using var content = new MultipartFormDataContent();
        content.Add(new StringContent(TranscribeModel), "model");

        var fileContent = new ByteArrayContent(wavData);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        content.Add(fileContent, "file", "audio.wav");

        using var request = new HttpRequestMessage(HttpMethod.Post, TranscribeUrl)
        {
            Content = content
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey.Trim());

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Groq transcription failed ({(int)response.StatusCode}): {body}");
        }

        using var document = JsonDocument.Parse(body);
        if (!document.RootElement.TryGetProperty("text", out var textElement))
        {
            throw new InvalidOperationException("Groq transcription response did not include text.");
        }

        var text = textElement.GetString()?.Trim();
        if (string.IsNullOrWhiteSpace(text))
        {
            throw new InvalidOperationException("Groq transcription response returned empty text.");
        }

        return text;
    }

    public async Task<string> RewriteAsync(string transcript, string instructions, string apiKey, CancellationToken cancellationToken)
    {
        ValidateApiKey(apiKey);

        var payload = new
        {
            model = RewriteModel,
            temperature = 0.0,
            messages = new[]
            {
                new { role = "system", content = instructions },
                new { role = "user", content = transcript }
            }
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, RewriteUrl)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey.Trim());

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Groq rewrite failed ({(int)response.StatusCode}): {body}");
        }

        return ParseCompletionText(body);
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    private static void ValidateApiKey(string apiKey)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new InvalidOperationException("Groq API key is missing.");
        }
    }

    private static string ParseCompletionText(string json)
    {
        using var document = JsonDocument.Parse(json);

        if (!document.RootElement.TryGetProperty("choices", out var choices) || choices.ValueKind != JsonValueKind.Array || choices.GetArrayLength() == 0)
        {
            throw new InvalidOperationException("Groq rewrite payload had no choices.");
        }

        var message = choices[0].GetProperty("message");
        if (!message.TryGetProperty("content", out var content))
        {
            throw new InvalidOperationException("Groq rewrite payload had no message content.");
        }

        if (content.ValueKind == JsonValueKind.String)
        {
            var text = content.GetString()?.Trim();
            if (!string.IsNullOrWhiteSpace(text))
            {
                return text;
            }
        }

        if (content.ValueKind == JsonValueKind.Array)
        {
            var builder = new StringBuilder();
            foreach (var item in content.EnumerateArray())
            {
                if (item.ValueKind == JsonValueKind.Object && item.TryGetProperty("text", out var textElement))
                {
                    var textPart = textElement.GetString();
                    if (!string.IsNullOrWhiteSpace(textPart))
                    {
                        builder.Append(textPart);
                    }
                }
            }

            var merged = builder.ToString().Trim();
            if (!string.IsNullOrWhiteSpace(merged))
            {
                return merged;
            }
        }

        throw new InvalidOperationException("Unable to parse Groq rewrite response text.");
    }
}

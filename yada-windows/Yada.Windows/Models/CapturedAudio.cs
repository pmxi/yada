namespace Yada.Windows.Models;

public sealed record CapturedAudio(byte[] PcmData, int SampleRate, int Channels, int BitsPerSample)
{
    public static CapturedAudio Empty { get; } = new([], 16_000, 1, 16);
}

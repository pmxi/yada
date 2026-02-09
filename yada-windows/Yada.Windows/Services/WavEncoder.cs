namespace Yada.Windows.Services;

public static class WavEncoder
{
    public static byte[] Encode(byte[] pcmData, int sampleRate, int channels, int bitsPerSample)
    {
        var byteRate = sampleRate * channels * bitsPerSample / 8;
        var blockAlign = channels * bitsPerSample / 8;
        var dataLength = pcmData.Length;

        using var stream = new MemoryStream();
        using var writer = new BinaryWriter(stream);

        writer.Write("RIFF"u8.ToArray());
        writer.Write(36 + dataLength);
        writer.Write("WAVE"u8.ToArray());

        writer.Write("fmt "u8.ToArray());
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)channels);
        writer.Write(sampleRate);
        writer.Write(byteRate);
        writer.Write((short)blockAlign);
        writer.Write((short)bitsPerSample);

        writer.Write("data"u8.ToArray());
        writer.Write(dataLength);
        writer.Write(pcmData);

        writer.Flush();
        return stream.ToArray();
    }
}

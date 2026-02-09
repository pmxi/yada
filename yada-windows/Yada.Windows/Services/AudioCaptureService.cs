using NAudio.Wave;
using Yada.Windows.Models;

namespace Yada.Windows.Services;

public sealed class AudioCaptureService : IDisposable
{
    private WaveInEvent? _waveIn;
    private MemoryStream? _pcmBuffer;

    public IReadOnlyList<AudioInputDevice> GetInputDevices()
    {
        var devices = new List<AudioInputDevice>();
        for (var i = 0; i < WaveInEvent.DeviceCount; i++)
        {
            var capabilities = WaveInEvent.GetCapabilities(i);
            devices.Add(new AudioInputDevice
            {
                Index = i,
                Name = capabilities.ProductName
            });
        }

        return devices;
    }

    public void Start(int? deviceIndex)
    {
        if (_waveIn is not null)
        {
            throw new InvalidOperationException("Recording is already in progress.");
        }

        if (WaveInEvent.DeviceCount == 0)
        {
            throw new InvalidOperationException("No input devices were found.");
        }

        var index = deviceIndex ?? 0;
        if (index < 0 || index >= WaveInEvent.DeviceCount)
        {
            throw new ArgumentOutOfRangeException(nameof(deviceIndex), "Invalid input device index.");
        }

        _pcmBuffer = new MemoryStream();
        _waveIn = new WaveInEvent
        {
            DeviceNumber = index,
            WaveFormat = new WaveFormat(16_000, 16, 1),
            BufferMilliseconds = 60,
            NumberOfBuffers = 3
        };
        _waveIn.DataAvailable += OnDataAvailable;
        _waveIn.StartRecording();
    }

    public async Task<CapturedAudio> StopAsync(CancellationToken cancellationToken = default)
    {
        if (_waveIn is null || _pcmBuffer is null)
        {
            return CapturedAudio.Empty;
        }

        var waveIn = _waveIn;
        var pcmBuffer = _pcmBuffer;

        _waveIn = null;
        _pcmBuffer = null;

        var stopSignal = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        EventHandler<StoppedEventArgs>? stoppedHandler = null;
        stoppedHandler = (_, _) => stopSignal.TrySetResult();

        waveIn.RecordingStopped += stoppedHandler;
        waveIn.StopRecording();

        try
        {
            await stopSignal.Task.WaitAsync(TimeSpan.FromSeconds(2), cancellationToken);
        }
        catch
        {
            // If the stop callback never arrives, proceed with whatever buffer we have.
        }

        waveIn.RecordingStopped -= stoppedHandler;
        waveIn.DataAvailable -= OnDataAvailable;
        waveIn.Dispose();

        return new CapturedAudio(
            PcmData: pcmBuffer.ToArray(),
            SampleRate: 16_000,
            Channels: 1,
            BitsPerSample: 16);
    }

    public void Dispose()
    {
        if (_waveIn is null)
        {
            return;
        }

        _waveIn.DataAvailable -= OnDataAvailable;
        _waveIn.Dispose();
        _waveIn = null;
        _pcmBuffer = null;
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs args)
    {
        _pcmBuffer?.Write(args.Buffer, 0, args.BytesRecorded);
    }
}

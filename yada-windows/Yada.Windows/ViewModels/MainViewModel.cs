using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Dispatching;
using Yada.Windows.Models;
using Yada.Windows.Services;

namespace Yada.Windows.ViewModels;

public sealed class MainViewModel : ObservableObject, IDisposable
{
    private readonly DispatcherQueue _dispatcher;
    private readonly SettingsStore _settingsStore;
    private readonly AudioCaptureService _audioCapture;
    private readonly GroqClient _groqClient;
    private readonly TextInserter _textInserter;
    private readonly HotKeyService _hotKeyService;

    private AppStatus _status = AppStatus.Idle;
    private string _statusDetail = string.Empty;
    private string _apiKey = string.Empty;
    private string _rewritePrompt = AppDefaults.RewritePrompt;
    private AudioInputDevice? _selectedInputDevice;
    private HotKeyMode _hotKeyMode = HotKeyMode.Toggle;
    private HotKeyConfig _hotKey = HotKeyConfig.Default;

    public MainViewModel(DispatcherQueue dispatcher)
    {
        _dispatcher = dispatcher;
        _settingsStore = new SettingsStore();
        _audioCapture = new AudioCaptureService();
        _groqClient = new GroqClient();
        _textInserter = new TextInserter();
        _hotKeyService = new HotKeyService();

        ToggleRecordingCommand = new AsyncRelayCommand(ToggleRecordingAsync, CanToggleRecording);
        SaveSettingsCommand = new AsyncRelayCommand(SaveSettingsAsync);

        HotKeyModes = Enum.GetValues<HotKeyMode>();

        _hotKeyService.Pressed += OnHotKeyPressed;
        _hotKeyService.Released += OnHotKeyReleased;
    }

    public ObservableCollection<AudioInputDevice> InputDevices { get; } = [];

    public IReadOnlyList<HotKeyMode> HotKeyModes { get; }

    public IAsyncRelayCommand ToggleRecordingCommand { get; }

    public IAsyncRelayCommand SaveSettingsCommand { get; }

    public AppStatus Status
    {
        get => _status;
        private set
        {
            if (!SetProperty(ref _status, value))
            {
                return;
            }

            OnPropertyChanged(nameof(StatusLabel));
            OnPropertyChanged(nameof(ToggleButtonText));
            ToggleRecordingCommand.NotifyCanExecuteChanged();
        }
    }

    public string StatusDetail
    {
        get => _statusDetail;
        private set => SetProperty(ref _statusDetail, value);
    }

    public string ApiKey
    {
        get => _apiKey;
        set => SetProperty(ref _apiKey, value);
    }

    public string RewritePrompt
    {
        get => _rewritePrompt;
        set => SetProperty(ref _rewritePrompt, value);
    }

    public AudioInputDevice? SelectedInputDevice
    {
        get => _selectedInputDevice;
        set => SetProperty(ref _selectedInputDevice, value);
    }

    public HotKeyMode HotKeyMode
    {
        get => _hotKeyMode;
        set => SetProperty(ref _hotKeyMode, value);
    }

    public string StatusLabel => Status switch
    {
        AppStatus.Idle => "Status: Idle",
        AppStatus.Recording => "Status: Recording",
        AppStatus.Transcribing => "Status: Transcribing",
        AppStatus.Rewriting => "Status: Rewriting",
        AppStatus.Inserting => "Status: Inserting",
        AppStatus.Error => "Status: Error",
        _ => "Status: Unknown"
    };

    public string ToggleButtonText => Status == AppStatus.Recording ? "Stop Recording" : "Start Recording";

    public async Task InitializeAsync()
    {
        var settings = await _settingsStore.LoadAsync();

        ApiKey = settings.ApiKey;
        RewritePrompt = string.IsNullOrWhiteSpace(settings.RewritePrompt) ? AppDefaults.RewritePrompt : settings.RewritePrompt;
        HotKeyMode = settings.HotKeyMode;
        _hotKey = new HotKeyConfig(settings.HotKeyVirtualKey, settings.HotKeyModifiers);
        _hotKeyService.UpdateHotKey(_hotKey);

        RefreshInputDevices(settings.SelectedInputDeviceIndex);
        Status = AppStatus.Idle;
        StatusDetail = "Ready. Use Ctrl+Shift+Space.";
    }

    public void Dispose()
    {
        _hotKeyService.Pressed -= OnHotKeyPressed;
        _hotKeyService.Released -= OnHotKeyReleased;
        _hotKeyService.Dispose();
        _audioCapture.Dispose();
        _groqClient.Dispose();
    }

    private async Task ToggleRecordingAsync()
    {
        switch (Status)
        {
            case AppStatus.Idle:
            case AppStatus.Error:
                await StartRecordingAsync();
                break;
            case AppStatus.Recording:
                await StopAndProcessAsync();
                break;
        }
    }

    private bool CanToggleRecording()
    {
        return Status is AppStatus.Idle or AppStatus.Error or AppStatus.Recording;
    }

    private Task StartRecordingAsync()
    {
        if (string.IsNullOrWhiteSpace(ApiKey))
        {
            SetError("Groq API key is missing.");
            return Task.CompletedTask;
        }

        try
        {
            _audioCapture.Start(SelectedInputDevice?.Index);
            Status = AppStatus.Recording;
            StatusDetail = "Listening...";
        }
        catch (Exception ex)
        {
            SetError($"Audio start failed: {ex.Message}");
        }

        return Task.CompletedTask;
    }

    private async Task StopAndProcessAsync()
    {
        CapturedAudio captured;

        try
        {
            captured = await _audioCapture.StopAsync();
        }
        catch (Exception ex)
        {
            SetError($"Audio stop failed: {ex.Message}");
            return;
        }

        if (captured.PcmData.Length == 0)
        {
            SetError("No audio was captured.");
            return;
        }

        var apiKey = ApiKey.Trim();
        var instructions = string.IsNullOrWhiteSpace(RewritePrompt) ? AppDefaults.RewritePrompt : RewritePrompt;

        try
        {
            Status = AppStatus.Transcribing;
            StatusDetail = "Transcribing with Groq whisper-large-v3...";

            var wavData = WavEncoder.Encode(captured.PcmData, captured.SampleRate, captured.Channels, captured.BitsPerSample);
            var transcript = await _groqClient.TranscribeAsync(wavData, apiKey, CancellationToken.None);

            Status = AppStatus.Rewriting;
            StatusDetail = "Rewriting with moonshotai/kimi-k2-instruct...";

            var rewritten = await _groqClient.RewriteAsync(transcript, instructions, apiKey, CancellationToken.None);

            Status = AppStatus.Inserting;
            StatusDetail = "Inserting text...";

            if (!_textInserter.Insert(rewritten))
            {
                SetError("Failed to insert text at cursor.");
                return;
            }

            Status = AppStatus.Idle;
            StatusDetail = "Done.";
        }
        catch (Exception ex)
        {
            SetError(ex.Message);
        }
    }

    private async Task SaveSettingsAsync()
    {
        var model = new SettingsModel
        {
            ApiKey = ApiKey.Trim(),
            RewritePrompt = string.IsNullOrWhiteSpace(RewritePrompt) ? AppDefaults.RewritePrompt : RewritePrompt,
            SelectedInputDeviceIndex = SelectedInputDevice?.Index,
            HotKeyMode = HotKeyMode,
            HotKeyVirtualKey = _hotKey.VirtualKey,
            HotKeyModifiers = _hotKey.Modifiers
        };

        await _settingsStore.SaveAsync(model);
        StatusDetail = "Settings saved.";
    }

    private void OnHotKeyPressed()
    {
        _dispatcher.TryEnqueue(() =>
        {
            if (HotKeyMode == HotKeyMode.Toggle)
            {
                _ = ToggleRecordingAsync();
                return;
            }

            if (Status == AppStatus.Idle || Status == AppStatus.Error)
            {
                _ = StartRecordingAsync();
            }
        });
    }

    private void OnHotKeyReleased()
    {
        _dispatcher.TryEnqueue(() =>
        {
            if (HotKeyMode == HotKeyMode.Hold && Status == AppStatus.Recording)
            {
                _ = StopAndProcessAsync();
            }
        });
    }

    private void RefreshInputDevices(int? selectedIndex)
    {
        InputDevices.Clear();
        foreach (var device in _audioCapture.GetInputDevices())
        {
            InputDevices.Add(device);
        }

        SelectedInputDevice = selectedIndex.HasValue
            ? InputDevices.FirstOrDefault(x => x.Index == selectedIndex.Value)
            : InputDevices.FirstOrDefault();
    }

    private void SetError(string message)
    {
        Status = AppStatus.Error;
        StatusDetail = message;
    }
}

namespace Yada.Windows.Models;

public sealed class SettingsModel
{
    public string ApiKey { get; set; } = string.Empty;

    public string RewritePrompt { get; set; } = AppDefaults.RewritePrompt;

    public int? SelectedInputDeviceIndex { get; set; }

    public HotKeyMode HotKeyMode { get; set; } = HotKeyMode.Toggle;

    public uint HotKeyVirtualKey { get; set; } = HotKeyConfig.Default.VirtualKey;

    public HotKeyModifiers HotKeyModifiers { get; set; } = HotKeyConfig.Default.Modifiers;
}

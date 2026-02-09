namespace Yada.Windows.Models;

public readonly record struct HotKeyConfig(uint VirtualKey, HotKeyModifiers Modifiers)
{
    public static HotKeyConfig Default => new(0x20, HotKeyModifiers.Control | HotKeyModifiers.Shift); // Ctrl+Shift+Space
}

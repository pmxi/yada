namespace Yada.Windows.Models;

[Flags]
public enum HotKeyModifiers
{
    None = 0,
    Control = 1,
    Alt = 2,
    Shift = 4,
    Win = 8
}

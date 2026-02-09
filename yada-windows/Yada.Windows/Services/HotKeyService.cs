using System.Runtime.InteropServices;
using Yada.Windows.Models;
using Yada.Windows.Utils;

namespace Yada.Windows.Services;

public sealed class HotKeyService : IDisposable
{
    private readonly NativeMethods.LowLevelKeyboardProc _hookProc;
    private nint _hookHandle;
    private HotKeyConfig _hotKey;
    private bool _isPressed;

    public event Action? Pressed;

    public event Action? Released;

    public HotKeyService()
    {
        _hotKey = HotKeyConfig.Default;
        _hookProc = HookCallback;
        _hookHandle = NativeMethods.SetKeyboardHook(_hookProc);
        if (_hookHandle == nint.Zero)
        {
            throw new InvalidOperationException($"Unable to install keyboard hook. Win32 error: {Marshal.GetLastWin32Error()}");
        }
    }

    public void UpdateHotKey(HotKeyConfig hotKey)
    {
        _hotKey = hotKey;
        _isPressed = false;
    }

    public void Dispose()
    {
        if (_hookHandle == nint.Zero)
        {
            return;
        }

        NativeMethods.UnhookWindowsHookEx(_hookHandle);
        _hookHandle = nint.Zero;
    }

    private nint HookCallback(int nCode, nuint wParam, nint lParam)
    {
        if (nCode < 0)
        {
            return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
        }

        var message = (uint)wParam;
        var isDown = message == NativeMethods.WM_KEYDOWN || message == NativeMethods.WM_SYSKEYDOWN;
        var isUp = message == NativeMethods.WM_KEYUP || message == NativeMethods.WM_SYSKEYUP;

        var data = Marshal.PtrToStructure<NativeMethods.KBDLLHOOKSTRUCT>(lParam);
        if (data.vkCode == _hotKey.VirtualKey)
        {
            if (isDown && !_isPressed && AreModifiersPressed(_hotKey.Modifiers))
            {
                _isPressed = true;
                Pressed?.Invoke();
            }
            else if (isUp && _isPressed)
            {
                _isPressed = false;
                Released?.Invoke();
            }
        }
        else if (isUp && _isPressed && !AreModifiersPressed(_hotKey.Modifiers))
        {
            _isPressed = false;
            Released?.Invoke();
        }

        return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private static bool AreModifiersPressed(HotKeyModifiers required)
    {
        if (required.HasFlag(HotKeyModifiers.Control) && !IsAnyDown(NativeMethods.VK_LCONTROL, NativeMethods.VK_RCONTROL, NativeMethods.VK_CONTROL))
        {
            return false;
        }

        if (required.HasFlag(HotKeyModifiers.Shift) && !IsAnyDown(NativeMethods.VK_LSHIFT, NativeMethods.VK_RSHIFT, NativeMethods.VK_SHIFT))
        {
            return false;
        }

        if (required.HasFlag(HotKeyModifiers.Alt) && !IsAnyDown(NativeMethods.VK_LMENU, NativeMethods.VK_RMENU, NativeMethods.VK_MENU))
        {
            return false;
        }

        if (required.HasFlag(HotKeyModifiers.Win) && !IsAnyDown(NativeMethods.VK_LWIN, NativeMethods.VK_RWIN))
        {
            return false;
        }

        return true;
    }

    private static bool IsAnyDown(params int[] keys)
    {
        foreach (var key in keys)
        {
            if (NativeMethods.IsVirtualKeyDown(key))
            {
                return true;
            }
        }

        return false;
    }
}

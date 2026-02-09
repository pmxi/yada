using Windows.ApplicationModel.DataTransfer;
using Yada.Windows.Utils;

namespace Yada.Windows.Services;

public sealed class TextInserter
{
    public bool Insert(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        var package = new DataPackage();
        package.SetText(text);
        Clipboard.SetContent(package);
        Clipboard.Flush();

        Thread.Sleep(20);
        return NativeMethods.SendCtrlV();
    }
}

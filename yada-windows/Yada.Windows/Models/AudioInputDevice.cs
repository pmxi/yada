namespace Yada.Windows.Models;

public sealed class AudioInputDevice
{
    public required int Index { get; init; }

    public required string Name { get; init; }

    public override string ToString() => Name;
}

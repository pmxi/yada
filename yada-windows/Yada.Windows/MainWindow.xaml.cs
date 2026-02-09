using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Yada.Windows.ViewModels;

namespace Yada.Windows;

public sealed partial class MainWindow : Window
{
    public MainViewModel ViewModel { get; }

    private bool _initialized;

    public MainWindow()
    {
        ViewModel = new MainViewModel(DispatcherQueue.GetForCurrentThread());
        InitializeComponent();
        Activated += OnActivated;
        Closed += OnClosed;
    }

    private async void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        if (_initialized)
        {
            return;
        }

        _initialized = true;
        await ViewModel.InitializeAsync();
    }

    private void OnClosed(object sender, WindowEventArgs args)
    {
        ViewModel.Dispose();
    }
}

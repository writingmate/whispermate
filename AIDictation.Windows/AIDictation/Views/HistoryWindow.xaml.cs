using System.Windows;
using AIDictation.ViewModels;

namespace AIDictation.Views;

/// <summary>
/// History window displaying all past recordings with search, copy, and delete functionality.
/// </summary>
public partial class HistoryWindow : Window
{
    public HistoryWindow()
    {
        InitializeComponent();
    }

    /// <summary>
    /// Gets the ViewModel for external access.
    /// </summary>
    public HistoryViewModel ViewModel => (HistoryViewModel)DataContext;

    /// <summary>
    /// Refreshes the history list when the window is shown.
    /// </summary>
    protected override void OnActivated(System.EventArgs e)
    {
        base.OnActivated(e);
        ViewModel.Refresh();
    }
}

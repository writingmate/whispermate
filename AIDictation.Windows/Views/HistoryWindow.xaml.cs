using System.Windows;
using AIDictation.Services;

namespace AIDictation.Views;

public partial class HistoryWindow : Window
{
    private readonly HistoryService _historyService;

    public HistoryWindow()
    {
        InitializeComponent();

        _historyService = HistoryService.Instance;
        _historyService.HistoryChanged += OnHistoryChanged;

        RefreshList();
    }

    private void OnHistoryChanged(object? sender, System.EventArgs e)
    {
        Dispatcher.Invoke(RefreshList);
    }

    private void RefreshList()
    {
        var searchText = SearchBox?.Text ?? "";
        var entries = string.IsNullOrWhiteSpace(searchText)
            ? _historyService.Entries
            : _historyService.Search(searchText);

        RecordingsList.ItemsSource = entries;

        // Update empty state
        EmptyState.Visibility = entries.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        RecordingsList.Visibility = entries.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

        // Update count
        RecordingCount.Text = $"{entries.Count} recording{(entries.Count == 1 ? "" : "s")}";
    }

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        RefreshList();
    }

    private void CopyItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is RecordingEntry entry)
        {
            if (!string.IsNullOrEmpty(entry.Transcription))
            {
                ClipboardService.Instance.CopyToClipboard(entry.Transcription);
            }
        }
    }

    private void DeleteItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is RecordingEntry entry)
        {
            _historyService.DeleteEntry(entry.Id);
        }
    }

    private void ClearAll_Click(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            "Are you sure you want to delete all recordings? This cannot be undone.",
            "Clear History",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            _historyService.ClearHistory();
        }
    }

    protected override void OnClosed(System.EventArgs e)
    {
        _historyService.HistoryChanged -= OnHistoryChanged;
        base.OnClosed(e);
    }
}

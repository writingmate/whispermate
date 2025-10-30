import SwiftUI

struct HistoryWindowView: View {
    @StateObject private var historyManager = HistoryManager()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HistoryView(historyManager: historyManager)
            .onAppear {
                // Set window identifier for identification
                if let window = NSApplication.shared.windows.first(where: { $0.title == "History" }) {
                    window.identifier = WindowIdentifiers.history
                }
            }
    }
}

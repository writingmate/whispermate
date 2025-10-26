import SwiftUI

struct HistoryWindowView: View {
    @StateObject private var historyManager = HistoryManager()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HistoryView(historyManager: historyManager)
    }
}

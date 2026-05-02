import SwiftUI

/// Displays the last 50 translations loaded from the JSON history file.
/// Opens as a standalone NSWindow so it doesn't interfere with the popover.
struct HistoryView: View {
    @State private var entries: [TranslationResult] = []
    @State private var searchText = ""

    private var filtered: [TranslationResult] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.sourceText.localizedCaseInsensitiveContains(searchText) ||
            $0.translatedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .frame(width: 440, height: 440)
        .onAppear(perform: loadFromDisk)
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search history…", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        Text(entries.isEmpty ? "No translation history yet." : "No results for \"\(searchText)\".")
            .foregroundStyle(.secondary)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        List(filtered.indices, id: \.self) { i in
            HistoryRowView(result: filtered[i])
        }
        .listStyle(.plain)
    }

    // MARK: - Data

    private func loadFromDisk() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FastTranslate/history.json"),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([TranslationResult].self, from: data)
        else { return }
        entries = loaded
    }
}

struct HistoryRowView: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(result.sourceLanguage.displayName) → \(result.targetLanguage.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(result.sourceText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(result.translatedText)
                .font(.system(size: 13))
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
    }
}

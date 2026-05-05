import SwiftUI
import AppKit

/// Displays saved translations loaded from the JSON history file.
/// Opens as a standalone NSWindow so it doesn't interfere with the popover.
struct HistoryView: View {
    @State private var entries: [TranslationResult] = []
    @State private var searchText = ""
    @State private var selectedID: String?
    @State private var copiedMessage: String?
    @State private var isShowingClearConfirmation = false
    @State private var isSelecting = false
    @State private var selectedForDeletion = Set<String>()

    private var filtered: [HistoryEntry] {
        let mapped = entries.enumerated().map { index, result in
            HistoryEntry(id: "\(result.timestamp.timeIntervalSince1970)-\(index)", result: result)
        }
        guard !searchText.isEmpty else { return mapped }
        return mapped.filter {
            $0.result.sourceText.localizedCaseInsensitiveContains(searchText) ||
            $0.result.translatedText.localizedCaseInsensitiveContains(searchText) ||
            $0.result.sourceLanguage.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.result.targetLanguage.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedEntry: HistoryEntry? {
        filtered.first { $0.id == selectedID } ?? filtered.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.45)
            detailPane
        }
        .frame(width: 780, height: 520)
        .background(HistoryBackground())
        .onAppear(perform: loadFromDisk)
        .onChange(of: filtered.map(\.id)) { _, ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 24, weight: .bold))
                    Text("\(entries.count) saved translations")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(isSelecting ? "Done" : "Select") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSelecting.toggle()
                        selectedForDeletion.removeAll()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entries.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.regularMaterial, in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).stroke(.primary.opacity(0.08), lineWidth: 1) }
                .disabled(entries.isEmpty)
                .help(isSelecting ? "Exit selection" : "Select translations")
            }

            if isSelecting {
                selectionToolbar
            }

            searchBar

            if filtered.isEmpty {
                emptyListState
            } else {
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { entry in
                            HistoryRowView(
                                result: entry.result,
                                isSelected: selectedEntry?.id == entry.id,
                                isSelecting: isSelecting,
                                isMarked: selectedForDeletion.contains(entry.id)
                            ) {
                                if isSelecting {
                                    toggleSelection(entry.id)
                                } else {
                                    selectedID = entry.id
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .frame(width: 310)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Clear all translation history?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive, action: clearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved translations from this Mac. This action cannot be undone.")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search history...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 10) {
            Button(selectedForDeletion.count == filtered.count ? "Deselect All" : "Select All") {
                if selectedForDeletion.count == filtered.count {
                    selectedForDeletion.removeAll()
                } else {
                    selectedForDeletion = Set(filtered.map(\.id))
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))

            Spacer()

            Text("\(selectedForDeletion.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                isShowingClearConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedForDeletion.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
            .disabled(selectedForDeletion.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var emptyListState: some View {
        VStack(spacing: 10) {
            Image(systemName: entries.isEmpty ? "clock.badge.questionmark" : "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(entries.isEmpty ? "No translations yet" : "No matching results")
                .font(.system(size: 13, weight: .semibold))
            Text(entries.isEmpty ? "Translate something and it will appear here." : "Try another keyword or language name.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail

    private var detailPane: some View {
        Group {
            if let entry = selectedEntry {
                HistoryDetailView(
                    result: entry.result,
                    copiedMessage: copiedMessage,
                    copyAction: copyText
                )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("Select a translation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copyText(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedMessage = "Copied \(label)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if copiedMessage == "Copied \(label)" {
                copiedMessage = nil
            }
        }
    }

    private func clearHistory() {
        if isSelecting {
            deleteSelectedHistoryItems()
            return
        }

        entries = []
        selectedID = nil
        searchText = ""
        copiedMessage = nil

        guard let url = historyFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func deleteSelectedHistoryItems() {
        let deleting = Set(filtered.filter { selectedForDeletion.contains($0.id) }.map { $0.identity })
        entries.removeAll { deleting.contains(HistoryEntry.identity(for: $0)) }

        if let currentSelectedID = selectedID, selectedForDeletion.contains(currentSelectedID) {
            self.selectedID = filtered.first?.id
        }
        selectedForDeletion.removeAll()
        isSelecting = false
        saveHistoryToDisk()
    }

    private func toggleSelection(_ id: String) {
        if selectedForDeletion.contains(id) {
            selectedForDeletion.remove(id)
        } else {
            selectedForDeletion.insert(id)
        }
    }

    // MARK: - Data

    private func loadFromDisk() {
        guard let url = historyFileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([TranslationResult].self, from: data)
        else { return }
        entries = loaded
        selectedID = filtered.first?.id
    }

    private func historyFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FastTranslate/history.json")
    }

    private func saveHistoryToDisk() {
        guard let url = historyFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private struct HistoryEntry: Identifiable {
    let id: String
    let result: TranslationResult

    var identity: String { Self.identity(for: result) }

    static func identity(for result: TranslationResult) -> String {
        "\(result.timestamp.timeIntervalSince1970)|\(result.sourceText)|\(result.translatedText)"
    }
}

private struct HistoryRowView: View {
    let result: TranslationResult
    let isSelected: Bool
    let isSelecting: Bool
    let isMarked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if isSelecting {
                        Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isMarked ? AnyShapeStyle(.blue) : AnyShapeStyle(.tertiary))
                    }

                    Text("\(result.sourceLanguage.shortName) -> \(result.targetLanguage.shortName)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.background.opacity(isSelected ? 0.34 : 0.58), in: Capsule(style: .continuous))

                    Spacer()

                    Text(result.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(result.translatedText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(result.sourceText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(rowStrokeColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: some ShapeStyle {
        if isMarked { return AnyShapeStyle(.blue.opacity(0.10)) }
        return isSelected && !isSelecting ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.regularMaterial)
    }

    private var rowStrokeColor: Color {
        if isMarked { return .blue.opacity(0.35) }
        return isSelected && !isSelecting ? .primary.opacity(0.16) : .primary.opacity(0.07)
    }
}

private struct HistoryDetailView: View {
    let result: TranslationResult
    let copiedMessage: String?
    let copyAction: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailHeader

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    TextBlockCard(
                        title: "Source",
                        language: result.sourceLanguage.displayName,
                        text: result.sourceText,
                        copyTitle: "Copy Source"
                    ) {
                        copyAction(result.sourceText, "source")
                    }

                    TextBlockCard(
                        title: "Translation",
                        language: result.targetLanguage.displayName,
                        text: result.translatedText,
                        copyTitle: "Copy Translation",
                        isPrimary: true
                    ) {
                        copyAction(result.translatedText, "translation")
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation Detail")
                        .font(.system(size: 22, weight: .bold))
                    Text("\(result.sourceLanguage.displayName) -> \(result.targetLanguage.displayName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.timestamp, style: .date)
                        .font(.caption)
                    Text(result.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                CopyPillButton(title: "Copy All", systemImage: "doc.on.doc") {
                    copyAction("\(result.sourceText)\n\n\(result.translatedText)", "all")
                }
                CopyPillButton(title: "Copy Translation", systemImage: "text.quote") {
                    copyAction(result.translatedText, "translation")
                }

                Spacer()

                if let copiedMessage {
                    Text(copiedMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
        }
    }
}

private struct TextBlockCard: View {
    let title: String
    let language: String
    let text: String
    let copyTitle: String
    var isPrimary = false
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CopyPillButton(title: copyTitle, systemImage: "doc.on.doc", action: onCopy)
            }

            Text(text)
                .font(.system(size: isPrimary ? 14 : 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(14)
                .background(.background.opacity(isPrimary ? 0.52 : 0.36), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(isPrimary ? 0.12 : 0.08), lineWidth: 1)
        }
    }
}

private struct CopyPillButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.primary.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryBackground: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [.primary.opacity(0.035), .clear, .primary.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

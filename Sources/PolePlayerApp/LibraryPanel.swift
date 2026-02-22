import SwiftUI

struct LibraryPanel: View {
    let recentURLs: [URL]
    let currentURL: URL?
    let onOpen: () -> Void
    let onOpenRecent: (URL) -> Void
    let onClearRecents: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("Files")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.sectionLabel)
                    .kerning(0.6)
                Spacer()
                Button(action: onOpen) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Open file…")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().background(Theme.panelDivider)

            if recentURLs.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.12))
                    Text("No recent files")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recentURLs, id: \.self) { url in
                            RecentFileRow(
                                url: url,
                                isCurrent: url == currentURL,
                                onOpen: { onOpenRecent(url) }
                            )
                        }
                    }
                }

                Divider().background(Theme.panelDivider)

                Button("Clear Recents", action: onClearRecents)
                    .buttonStyle(.plain)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.4))
                    .padding(.vertical, 8)
            }
        }
        .background(.regularMaterial)
    }
}

private struct RecentFileRow: View {
    let url: URL
    let isCurrent: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: fileIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(isCurrent ? Color.accentColor : Theme.secondaryText.opacity(0.6))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(AppFont.caption)
                        .foregroundStyle(isCurrent ? Color.white : Theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.secondaryText.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isCurrent ? Color.white.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fileIcon: String {
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v": return "film"
        case "exr", "dpx":        return "doc.viewfinder"
        default:                  return "photo"
        }
    }
}

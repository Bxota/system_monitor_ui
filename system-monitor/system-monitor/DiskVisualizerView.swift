import Combine
import SwiftUI
import AppKit

// ---------------------------------------------------------------------------
// DiskVisualizerView — Visualise quels fichiers/dossiers prennent le plus de place
// Fonctionnalité Pro : accessible uniquement avec une licence active.
// ---------------------------------------------------------------------------

// MARK: – Data model

struct FileItem: Identifiable {
  let id   = UUID()
  let url  : URL
  let size : Int64
  let isDirectory: Bool

  var name         : String { url.lastPathComponent }
  var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }

  var iconName: String {
    if isDirectory { return "folder.fill" }
    switch url.pathExtension.lowercased() {
    case "jpg","jpeg","png","gif","heic","webp","tiff","bmp": return "photo.fill"
    case "mp4","mov","avi","mkv","m4v","wmv":                 return "play.rectangle.fill"
    case "mp3","aac","flac","wav","m4a","ogg":                return "music.note"
    case "zip","tar","gz","bz2","7z","rar","xz":              return "archivebox.fill"
    case "pdf":                                               return "doc.richtext.fill"
    case "app":                                               return "macwindow"
    case "dmg","pkg","iso":                                   return "externaldrive.fill"
    case "swift","py","js","ts","go","c","h","cpp","rb","rs": return "chevron.left.forwardslash.chevron.right"
    case "doc","docx","pages","txt","md":                     return "doc.text.fill"
    case "xls","xlsx","numbers","csv":                        return "tablecells.fill"
    case "ppt","pptx","key":                                  return "rectangle.on.rectangle.angled.fill"
    default:                                                  return "doc.fill"
    }
  }

  var iconColor: Color {
    if isDirectory { return .blue }
    switch url.pathExtension.lowercased() {
    case "jpg","jpeg","png","gif","heic","webp","tiff","bmp": return .pink
    case "mp4","mov","avi","mkv","m4v","wmv":                 return .purple
    case "mp3","aac","flac","wav","m4a","ogg":                return .yellow
    case "zip","tar","gz","bz2","7z","rar","xz":              return .orange
    case "pdf":                                               return .red
    case "app":                                               return .cyan
    case "dmg","pkg","iso":                                   return .teal
    case "swift","py","js","ts","go","c","h","cpp","rb","rs": return .green
    case "doc","docx","pages","txt","md":                     return .indigo
    case "xls","xlsx","numbers","csv":                        return Color(hue: 0.35, saturation: 0.7, brightness: 0.7)
    default:                                                  return .gray
    }
  }
}

// MARK: – ViewModel

@MainActor
final class DiskViewModel: ObservableObject {
  @Published var items      : [FileItem] = []
  @Published var isScanning : Bool = false
  @Published var selectedURL: URL = FileManager.default.homeDirectoryForCurrentUser
  @Published var errorMessage: String?

  var totalSize: Int64  { items.reduce(0) { $0 + $1.size } }
  var maxSize  : Int64  { items.first?.size ?? 1 }

  func pickFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles          = false
    panel.canChooseDirectories    = true
    panel.allowsMultipleSelection = false
    panel.directoryURL            = selectedURL
    panel.prompt                  = "Choisir"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    selectedURL = url
    Task { await scan() }
  }

  func scan() async {
    isScanning   = true
    errorMessage = nil
    let url      = selectedURL

    let results  = await Task.detached(priority: .userInitiated) {
      FileItem.scanDirectory(url)
    }.value

    items      = results
    isScanning = false
  }
}

// MARK: – Scan logic (off-main)

private extension FileItem {
  static func scanDirectory(_ url: URL) -> [FileItem] {
    guard let contents = try? FileManager.default.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return contents.compactMap { itemURL -> FileItem? in
      let rsrc  = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
      let isDir = rsrc?.isDirectory ?? false
      let size: Int64 = isDir
        ? directorySize(itemURL)
        : Int64(rsrc?.fileSize ?? 0)
      return FileItem(url: itemURL, size: size, isDirectory: isDir)
    }
    .sorted { $0.size > $1.size }
  }

  static func directorySize(_ url: URL) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [.fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else { return 0 }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let s = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        total += Int64(s)
      }
    }
    return total
  }
}

// MARK: – Main View

struct DiskVisualizerView: View {
  /// Le ViewModel est possédé par AppState et survit aux changements de navigation.
  @ObservedObject var vm: DiskViewModel

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      Divider()
      content
    }
    // Pas de .task : le scan n'est relancé que sur action explicite de l'utilisateur.
  }

  // MARK: Toolbar

  private var toolbar: some View {
    HStack(spacing: 12) {
      // Folder path pill
      HStack(spacing: 6) {
        Image(systemName: "folder.fill")
          .foregroundStyle(.blue)
          .font(.subheadline)
        Text(vm.selectedURL.path(percentEncoded: false))
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .onTapGesture { vm.pickFolder() }

      Spacer()

      // Stats
      if !vm.items.isEmpty {
        Text("\(vm.items.count) éléments · \(ByteCountFormatter.string(fromByteCount: vm.totalSize, countStyle: .file))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // Scan button
      Button {
        Task { await vm.scan() }
      } label: {
        Label("Scanner", systemImage: "arrow.clockwise")
          .font(.callout.weight(.medium))
      }
      .buttonStyle(.bordered)
      .disabled(vm.isScanning)

      Button("Choisir un dossier") { vm.pickFolder() }
        .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    if vm.isScanning {
      scanningView
    } else if vm.items.isEmpty {
      emptyView
    } else {
      fileList
    }
  }

  private var scanningView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)
      Text("Analyse en cours…")
        .font(.callout)
        .foregroundStyle(.secondary)
      Text(vm.selectedURL.path(percentEncoded: false))
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 18) {
      Image(systemName: "externaldrive.badge.plus")
        .font(.system(size: 44))
        .foregroundStyle(.secondary)

      VStack(spacing: 6) {
        Text("Aucun scan effectué")
          .font(.title3.weight(.semibold))
        Text("Lancez l'analyse pour voir quels fichiers occupent le plus de place.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 340)
      }

      Button {
        Task { await vm.scan() }
      } label: {
        Label("Analyser \"\(vm.selectedURL.lastPathComponent)\"", systemImage: "magnifyingglass")
          .font(.callout.weight(.medium))
          .padding(.horizontal, 4)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var fileList: some View {
    ScrollView {
      LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
        Section {
          ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
            FileRowView(item: item, maxSize: vm.maxSize, rank: index + 1) {
              if item.isDirectory {
                vm.selectedURL = item.url
                Task { await vm.scan() }
              } else {
                NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
              }
            }
            Divider().padding(.leading, 56)
          }
        } header: {
          SummaryHeader(total: vm.totalSize, count: vm.items.count)
        }
      }
      .padding(.bottom, 20)
    }
  }
}

// MARK: – Summary header

private struct SummaryHeader: View {
  let total: Int64
  let count: Int

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Espace occupé")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
          .font(.headline.weight(.bold))
      }
      Spacer()
      Text("\(count) éléments")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(.bar)
  }
}

// MARK: – File row

private struct FileRowView: View {
  let item   : FileItem
  let maxSize: Int64
  let rank   : Int
  let action : () -> Void

  private var barRatio: Double {
    guard maxSize > 0 else { return 0 }
    return min(Double(item.size) / Double(maxSize), 1.0)
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        // Rank
        Text("\(rank)")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.quaternary)
          .frame(width: 20, alignment: .trailing)

        // Icon
        Image(systemName: item.iconName)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(item.iconColor)
          .frame(width: 22, alignment: .center)

        // Name + bar
        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline) {
            Text(item.name)
              .font(.callout)
              .lineLimit(1)
            Spacer()
            Text(item.formattedSize)
              .font(.callout.monospacedDigit().weight(.medium))
              .foregroundStyle(.secondary)
          }

          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 5)
              Capsule()
                .fill(item.isDirectory ? Color.blue.gradient : item.iconColor.gradient)
                .frame(width: max(4, geo.size.width * barRatio), height: 5)
                .animation(.easeOut(duration: 0.4).delay(Double(rank) * 0.02), value: barRatio)
            }
          }
          .frame(height: 5)
        }

        // Chevron for directories
        if item.isDirectory {
          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
  }
}

// MARK: – Pro gate (si pas de licence)

struct ProGateView: View {
  let feature: String
  @EnvironmentObject private var licenseManager: LicenseManager
  @State private var showLicense = false

  var body: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(Color.orange.opacity(0.1))
          .frame(width: 72, height: 72)
        Image(systemName: "lock.fill")
          .font(.system(size: 28))
          .foregroundStyle(.orange)
      }

      VStack(spacing: 8) {
        Text("\(feature) — Pro")
          .font(.title2.weight(.bold))
        Text("Cette fonctionnalité nécessite une licence System Monitor Pro.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 340)
      }

      Button("Aller aux préférences") { showLicense = true }
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $showLicense) {
      PreferencesView()
        .environmentObject(licenseManager)
        .frame(minWidth: 520, minHeight: 640)
    }
  }
}

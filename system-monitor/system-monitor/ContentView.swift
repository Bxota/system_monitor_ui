import SwiftUI

// ---------------------------------------------------------------------------
// Navigation enum
// ---------------------------------------------------------------------------

enum NavItem: Hashable {
  case allMetrics
  case category(String)
  case diskVisualizer
  case preferences
}

// ---------------------------------------------------------------------------
// ContentView — racine de l'interface, injecte les @EnvironmentObject
// ---------------------------------------------------------------------------

struct ContentView: View {
  @EnvironmentObject private var service       : SysmonService
  @EnvironmentObject private var licenseManager: LicenseManager
  @EnvironmentObject private var diskViewModel : DiskViewModel

  @State private var selection    : NavItem? = .allMetrics
  @State private var searchText   : String   = ""

  private let gridColumns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

  var body: some View {
    NavigationSplitView {
      sidebarView
    } detail: {
      detailView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  // MARK: – Sidebar

  private var sidebarView: some View {
    List(selection: $selection) {
      // Vue d'ensemble
      Section("Vue d'ensemble") {
        NavRow(item: .allMetrics, title: "Toutes les métriques",
               icon: "list.bullet", color: .blue)
      }

      // Catégories dynamiques
      if !categories.isEmpty {
        Section("Catégories") {
          ForEach(categories, id: \.self) { cat in
            NavRow(item: .category(cat),
                   title: cat,
                   icon: categoryIcon(cat),
                   color: categoryColor(cat))
          }
        }
      }

      // Outils
      Section("Outils") {
        NavRow(item: .diskVisualizer,
               title: "Disk Visualizer",
               icon: "externaldrive.fill",
               color: .indigo,
               badge: licenseManager.isActivated ? nil : "PRO")
        NavRow(item: .preferences,
               title: "Préférences",
               icon: "gearshape.fill",
               color: .gray)
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("System Monitor")
  }

  // MARK: – Detail routing

  @ViewBuilder
  private var detailView: some View {
    switch selection ?? .allMetrics {
    case .allMetrics:
      metricsDetailView(title: "Toutes les métriques", metrics: filteredMetrics)
    case .category(let cat):
      metricsDetailView(title: cat, metrics: filteredMetrics)
    case .diskVisualizer:
      if licenseManager.isActivated {
        DiskVisualizerView(vm: diskViewModel)
      } else {
        ProGateView(feature: "Disk Visualizer")
      }
    case .preferences:
      PreferencesView()
    }
  }

  // MARK: – Metrics detail

  @ViewBuilder
  private func metricsDetailView(title: String, metrics: [Metric]) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Header
        headerView(title: title)

        // Error banner
        if let error = service.lastError {
          ErrorBanner(message: error)
        }

        // Dashboard hero cards (uniquement sur la vue "All")
        if (selection ?? .allMetrics) == .allMetrics, searchText.isEmpty {
          HeroDashboard(metrics: service.metrics)
        }

        // Metrics grid
        if metrics.isEmpty {
          EmptyStateView(
            title: "Aucune métrique",
            message: "En attente du premier snapshot ou ajustez vos filtres.",
            systemImage: "waveform.path.ecg"
          )
          .frame(maxWidth: .infinity, minHeight: 240)
        } else {
          LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(metrics) { metric in
              MetricCard(metric: metric)
            }
          }
        }
      }
      .padding(22)
    }
    .toolbar {
      ToolbarItemGroup {
        Button {
          service.refreshNow()
        } label: {
          Label("Rafraîchir", systemImage: "arrow.clockwise")
        }
        .help("Forcer un refresh immédiat")

        Button {
          service.togglePause()
        } label: {
          Label(
            service.isPaused ? "Reprendre" : "Pause",
            systemImage: service.isPaused ? "play.fill" : "pause.fill"
          )
        }
        .help(service.isPaused ? "Reprendre la collecte" : "Mettre en pause")
      }
    }
  }

  private func headerView(title: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(.largeTitle.weight(.bold))
          Text("\(service.metrics.count) métriques · refresh \(service.intervalMs) ms")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        StatusBadge(status: service.status, lastUpdated: service.lastUpdated)
      }

      // Search field — plain SwiftUI TextField avoids the NSSearchField focus bug
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.tertiary)
          .font(.callout)
        TextField("Rechercher une métrique…", text: $searchText)
          .textFieldStyle(.plain)
          .font(.callout)
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
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.quaternary))
    }
  }

  // MARK: – Helpers

  private var categories: [String] {
    Set(service.metrics.map { $0.category }).sorted()
  }

  private var filteredMetrics: [Metric] {
    let byCategory: [Metric]
    switch selection ?? .allMetrics {
    case .allMetrics:
      byCategory = service.metrics
    case .category(let cat):
      byCategory = service.metrics.filter { $0.category == cat }
    default:
      byCategory = service.metrics
    }
    guard !searchText.isEmpty else { return byCategory }
    return byCategory.filter {
      $0.displayName.localizedCaseInsensitiveContains(searchText) ||
      $0.name.localizedCaseInsensitiveContains(searchText)
    }
  }
}

// MARK: – Hero Dashboard (vue d'ensemble en haut)

private struct HeroDashboard: View {
  let metrics: [Metric]

  private let heroKeys = [
    "cpu.usage_percent", "ram.used_percent", "battery.percent", "storage.used_percent"
  ]

  private var heroMetrics: [Metric] {
    heroKeys.compactMap { key in metrics.first(where: { $0.name == key }) }
  }

  var body: some View {
    if heroMetrics.isEmpty { EmptyView() } else {
      VStack(alignment: .leading, spacing: 10) {
        Text("APERÇU RAPIDE")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .tracking(0.8)

        HStack(spacing: 14) {
          ForEach(heroMetrics) { metric in
            HeroCard(metric: metric)
          }
        }
      }
    }
  }
}

private struct HeroCard: View {
  let metric: Metric

  var body: some View {
    VStack(spacing: 10) {
      if let gauge = metric.gaugeValue {
        Gauge(value: gauge, in: 0...100) {
          EmptyView()
        } currentValueLabel: {
          Text(metric.displayValue)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
        }
        .tint(gaugeGradient)
        .gaugeStyle(.accessoryCircularCapacity)
        .frame(width: 64, height: 64)
      }

      Label(metric.displayName.capitalized, systemImage: metric.iconName)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(14)
    .background(categoryColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(categoryColor.opacity(0.15))
    )
  }

  private var categoryColor: Color { colorFor(metric.category) }

  private var gaugeGradient: Gradient {
    Gradient(colors: [categoryColor, categoryColor.opacity(0.5), .orange, .red])
  }
}

// MARK: – Metric Card (grille principale)

private struct MetricCard: View {
  let metric: Metric

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Icon badge + name
      HStack(spacing: 8) {
        Image(systemName: metric.iconName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(accentColor)
          .frame(width: 28, height: 28)
          .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

        Text(metric.displayName.capitalized)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      // Value / Gauge
      if let gauge = metric.gaugeValue {
        HStack(alignment: .bottom, spacing: 10) {
          Gauge(value: gauge, in: 0...100) {
            EmptyView()
          } currentValueLabel: {
            Text(metric.displayValue)
              .font(.headline)
              .contentTransition(.numericText())
          }
          .tint(Gradient(colors: [accentColor, accentColor.opacity(0.5), .orange, .red]))
          .gaugeStyle(.accessoryCircularCapacity)
          .frame(width: 54, height: 54)
          Spacer()
        }
      } else {
        Text(metric.displayValue)
          .font(.title2.weight(.bold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .contentTransition(.numericText())
      }

      Spacer(minLength: 0)

      // Raw name
      Text(metric.name)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
    .padding(14)
    .frame(minHeight: 120, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(accentColor.opacity(0.12))
    }
  }

  private var accentColor: Color { colorFor(metric.category) }
}

// MARK: – Status Badge

private struct StatusBadge: View {
  let status     : SysmonService.Status
  let lastUpdated: Date?

  var body: some View {
    VStack(alignment: .trailing, spacing: 5) {
      HStack(spacing: 7) {
        Circle().fill(statusColor).frame(width: 7, height: 7)
        Text(statusLabel).font(.callout.weight(.semibold))
      }
      if let d = lastUpdated {
        Text(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var statusLabel: String {
    switch status {
    case .idle:    return "En attente"
    case .running: return "En direct"
    case .paused:  return "Pause"
    case .error:   return "Erreur"
    }
  }

  private var statusColor: Color {
    switch status {
    case .idle:    return .gray
    case .running: return .green
    case .paused:  return .orange
    case .error:   return .red
    }
  }
}

// MARK: – Error Banner

private struct ErrorBanner: View {
  let message: String
  var body: some View {
    Label(message, systemImage: "exclamationmark.triangle.fill")
      .font(.callout).foregroundStyle(.red)
      .padding(12).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red.opacity(0.2)))
  }
}

// MARK: – Empty State

private struct EmptyStateView: View {
  let title: String; let message: String; let systemImage: String
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage).font(.system(size: 34, weight: .semibold)).foregroundStyle(.secondary)
      Text(title).font(.title3.weight(.semibold))
      Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
    }
    .padding(24)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

// MARK: – Nav Row (sidebar)

private struct NavRow: View {
  let item : NavItem
  let title: String
  let icon : String
  let color: Color
  var badge: String? = nil

  var body: some View {
    HStack {
      Label {
        Text(title)
      } icon: {
        Image(systemName: icon)
          .foregroundStyle(color)
      }
      if let badge {
        Spacer()
        Text(badge)
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 5).padding(.vertical, 2)
          .background(Color.orange, in: Capsule())
      }
    }
    .tag(item)
  }
}

// MARK: – Shared color / icon helpers

func colorFor(_ category: String) -> Color {
  switch category.lowercased() {
  case "cpu":               return .blue
  case "memory", "ram":     return .purple
  case "battery", "power":  return .green
  case "network", "net":    return .teal
  case "disk", "storage":   return .orange
  default:                  return Color.accentColor
  }
}

func categoryIcon(_ category: String) -> String {
  switch category.lowercased() {
  case "cpu":               return "cpu"
  case "memory", "ram":     return "memorychip"
  case "disk", "storage":   return "internaldrive"
  case "network", "net":    return "network"
  case "temperature","thermal","sensors": return "thermometer"
  case "battery", "power":  return "battery.100"
  case "fan", "cooling":    return "fanblades"
  default:                  return "waveform.path.ecg"
  }
}

func categoryColor(_ category: String) -> Color { colorFor(category) }

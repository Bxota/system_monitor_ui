import SwiftUI

// ---------------------------------------------------------------------------
// PreferencesView — Métrique top bar + Licence
// ---------------------------------------------------------------------------

/// Clé UserDefaults pour la métrique affichée dans le menu bar.
/// Valeurs possibles : "status" (défaut) ou un nom de métrique ex. "cpu.usage_percent"
let kMenuBarMetricKey = "menuBarMetricKey"

struct PreferencesView: View {
  @EnvironmentObject private var licenseManager: LicenseManager
  @AppStorage(kMenuBarMetricKey) private var metricKey: String = "status"

  // Options disponibles pour la top bar
  private let menuBarOptions: [(key: String, label: String, icon: String, color: Color)] = [
    ("status",               "État du service (défaut)", "circle.fill",    .green),
    ("cpu.usage_percent",    "CPU %",                    "cpu",            .blue),
    ("ram.used_percent",     "RAM %",                    "memorychip",     .purple),
    ("battery.percent",      "Batterie %",               "battery.100",    .green),
    ("storage.used_percent", "Stockage %",               "internaldrive",  .orange),
    ("network.rx_bytes_per_sec", "Réseau ↓",             "arrow.down.circle", .teal),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("Préférences")
          .font(.largeTitle.weight(.bold))
          .padding(.bottom, 28)

        // ── Section 1 : Barre de menu ──────────────────────────────────
        PrefSection(icon: "menubar.rectangle", title: "Barre de menu") {
          VStack(alignment: .leading, spacing: 10) {
            Text("Choisissez ce qui s'affiche dans l'icône de la barre de menu macOS.")
              .font(.callout)
              .foregroundStyle(.secondary)

            VStack(spacing: 2) {
              ForEach(menuBarOptions, id: \.key) { option in
                MenuBarOptionRow(
                  option: option,
                  isSelected: metricKey == option.key
                ) {
                  metricKey = option.key
                }
              }
            }
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary))

            // Aperçu
            HStack(spacing: 8) {
              Image(systemName: "eye")
                .foregroundStyle(.secondary)
                .font(.caption)
              Text("Aperçu dans le menu bar :")
                .font(.caption)
                .foregroundStyle(.secondary)
              MenuBarPreview(metricKey: metricKey)
            }
            .padding(.top, 4)
          }
        }

        Divider().padding(.vertical, 24)

        // ── Section 2 : Licence ───────────────────────────────────────
        PrefSection(icon: "key.fill", title: "Licence") {
          CompactLicenseSection()
        }

        Spacer(minLength: 40)
      }
      .frame(maxWidth: 560)
      .padding(32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

// MARK: – Option row

private struct MenuBarOptionRow: View {
  let option  : (key: String, label: String, icon: String, color: Color)
  let isSelected: Bool
  let action  : () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: option.icon)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isSelected ? option.color : .secondary)
          .frame(width: 24, alignment: .center)

        Text(option.label)
          .font(.callout)
          .foregroundStyle(isSelected ? .primary : .secondary)

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(
        isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: – Aperçu top bar (simulation visuelle)

private struct MenuBarPreview: View {
  let metricKey: String

  private var iconName: String {
    if metricKey == "status" { return "cpu" }
    if metricKey.contains("cpu")     { return "cpu" }
    if metricKey.contains("ram") || metricKey.contains("memory") { return "memorychip" }
    if metricKey.contains("battery") { return "battery.100" }
    if metricKey.contains("storage") { return "internaldrive" }
    if metricKey.contains("network") { return "arrow.down.circle" }
    return "chart.bar"
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: iconName)
        .font(.system(size: 12))
      if metricKey != "status" {
        Text("42%")
          .font(.system(size: 11, design: .monospaced))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary, lineWidth: 0.5))
  }
}

// MARK: – Compact licence section

private struct CompactLicenseSection: View {
  @EnvironmentObject private var licenseManager: LicenseManager
  @State private var inputKey  = ""
  @State private var errorMsg : String?
  @State private var shake     = false

  var body: some View {
    if licenseManager.isActivated {
      activatedView
    } else {
      activationForm
    }
  }

  private var activatedView: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .font(.title2)
        .foregroundStyle(.green)

      VStack(alignment: .leading, spacing: 3) {
        Text("Licence active")
          .font(.callout.weight(.semibold))
        Text(licenseManager.licensedTo)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("Désactiver") {
        licenseManager.deactivate()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .foregroundStyle(.red)
    }
    .padding(14)
    .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.2)))
  }

  private var activationForm: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "lock.fill")
          .foregroundStyle(.secondary)
        Text("Aucune licence active")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        TextField("email@example.com:MEUCIQDh…", text: $inputKey)
          .font(.system(.callout, design: .monospaced))
          .textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
          .onSubmit { tryActivate() }
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .strokeBorder(errorMsg != nil ? Color.red.opacity(0.5) : Color.clear)
          )
          .modifier(CompactShake(trigger: shake))

        Button("Activer", action: tryActivate)
          .buttonStyle(.borderedProminent)
          .controlSize(.regular)
          .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      if let err = errorMsg {
        Label(err, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }

      Button {
        inputKey = "demo@sysmon.app:ANlxnzC2g7qzutOUsBeDtGkORF+mvNq9c6Va2cjSH/I8gGvHZ/lxrIExEFdHs70Vcwrc5pDU7odf7K315Kn/fQ=="
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "wand.and.stars")
            .font(.caption)
          Text("Utiliser la clé de démonstration (demo@sysmon.app)")
            .font(.caption)
        }
        .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
    }
    .animation(.easeInOut(duration: 0.2), value: errorMsg)
  }

  private func tryActivate() {
    withAnimation { errorMsg = nil }
    if !licenseManager.activate(key: inputKey) {
      withAnimation { errorMsg = "Clé invalide — format attendu : email@example.com:signature" }
      shake.toggle()
    } else {
      inputKey = ""
    }
  }
}

// Shake compatible macOS 13 (dupliqué depuis LicenseView pour l'encapsulation)
private struct CompactShake: ViewModifier {
  let trigger: Bool
  @State private var count: Int = 0

  func body(content: Content) -> some View {
    content
      .modifier(CompactShakeEffect(shakes: count))
      .onChange(of: trigger) { _ in
        withAnimation(.easeOut(duration: 0.4)) { count += 1 }
      }
  }
}

private struct CompactShakeEffect: GeometryEffect {
  var shakes: Int
  var animatableData: CGFloat {
    get { CGFloat(shakes) }
    set { shakes = Int(newValue) }
  }
  func effectValue(size: CGSize) -> ProjectionTransform {
    let p = CGFloat(shakes).truncatingRemainder(dividingBy: 1)
    let a = 7.0 * sin(p * .pi * 6) * max(0, 1 - p)
    return ProjectionTransform(CGAffineTransform(translationX: a, y: 0))
  }
}

// MARK: – Section helper

struct PrefSection<Content: View>: View {
  let icon   : String
  let title  : String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: icon)
        .font(.headline.weight(.semibold))
      content()
    }
  }
}

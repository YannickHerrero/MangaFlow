import CoreText
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
  case holo, brutal, manga, terminal
  var id: String { rawValue }
  var name: String {
    switch self {
    case .holo: "Holographique"
    case .brutal: "Brutaliste"
    case .manga: "Planche manga"
    case .terminal: "Terminal"
    }
  }
  var detail: String {
    switch self {
    case .holo: "Pastels irisés, verre"
    case .brutal: "Grille brute, typo massive"
    case .manga: "Cases, trames, bulles"
    case .terminal: "Catppuccin · Latte / Mocha"
    }
  }
}
@Observable @MainActor
final class ThemeSettings {
  var theme: AppTheme { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") } }
  var appearance: String {
    didSet { UserDefaults.standard.set(appearance, forKey: "appAppearance") }
  }
  var scheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
  init() {
    theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "holo") ?? .holo
    appearance = UserDefaults.standard.string(forKey: "appAppearance") ?? "system"
    for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
struct ThemePalette {
  let theme: AppTheme
  let dark: Bool
  var ink: Color {
    if theme == .terminal { return Color(hex: dark ? 0xCDD6F4 : 0x4C4F69) }
    return Color(
      hex: dark ? (theme == .holo ? 0xF4F1FF : 0xF1EBDF) : (theme == .holo ? 0x17142B : 0x141210))
  }
  var paper: Color {
    if theme == .terminal { return Color(hex: dark ? 0x1E1E2E : 0xEFF1F5) }
    return Color(
      hex: theme == .holo
        ? (dark ? 0x1A1530 : 0xFFFFFF)
        : theme == .brutal ? (dark ? 0x0A0A0A : 0xF2F2EE) : (dark ? 0x141210 : 0xF1EBDF))
  }
  var surface: Color {
    if theme == .terminal { return Color(hex: dark ? 0x181825 : 0xE6E9EF) }
    return theme == .holo
      ? Color.white.opacity(dark ? 0.07 : 0.58)
      : Color(hex: theme == .brutal ? (dark ? 0x141414 : 0xFFFFFF) : (dark ? 0x1E1B18 : 0xFFFDF8))
  }
  var accent: Color {
    if theme == .terminal { return Color(hex: dark ? 0xA6E3A1 : 0x1E66F5) }
    return Color(
      hex: theme == .holo
        ? 0x6D4BFF : theme == .brutal ? (dark ? 0xD4FF00 : 0xFF3B00) : (dark ? 0xE8233F : 0xD7192F))
  }
  var muted: Color { Color(hex: dark ? 0xBAC2DE : 0x5C5F77) }
  var line: Color {
    theme == .terminal
      ? Color(hex: dark ? 0x585B70 : 0x9CA0B0)
      : theme == .holo ? .white.opacity(dark ? 0.18 : 0.9) : ink
  }
  var radius: CGFloat { theme == .holo ? 22 : theme == .manga ? 4 : 0 }
  var bodyFont: String {
    if theme == .terminal { return "SpaceMono-Regular" }
    return theme == .holo
      ? "SpaceGrotesk-Regular" : theme == .brutal ? "SpaceMono-Regular" : "ZenKakuGothicNew-Regular"
  }
  var titleFont: String {
    if theme == .terminal { return "SpaceMono-Regular" }
    return theme == .holo
      ? "SpaceGrotesk-Bold" : theme == .brutal ? "ArchivoBlack-Regular" : "Anton-Regular"
  }
  func font(_ size: CGFloat, title: Bool = false) -> Font {
    .custom(
      title ? titleFont : bodyFont,
      size: theme == .terminal ? min(max(size, 12), title ? 16 : 14) : size,
      relativeTo: title ? .title : .body)
  }
  var gradient: LinearGradient {
    LinearGradient(
      colors: [Color(hex: 0x6D4BFF), Color(hex: 0xE0399E)], startPoint: .leading,
      endPoint: .trailing)
  }
}
extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255)
  }
}
private struct PaletteKey: EnvironmentKey {
  static let defaultValue = ThemePalette(theme: .holo, dark: false)
}
extension EnvironmentValues {
  var palette: ThemePalette {
    get { self[PaletteKey.self] }
    set { self[PaletteKey.self] = newValue }
  }
}
struct ThemeHost<Content: View>: View {
  @Environment(ThemeSettings.self) private var settings
  @Environment(\.colorScheme) private var scheme
  @ViewBuilder let content: () -> Content
  var body: some View {
    let p = ThemePalette(theme: settings.theme, dark: scheme == .dark)
    content().environment(\.palette, p).font(p.font(14)).foregroundStyle(p.ink).tint(p.accent)
      .background { ThemeBackground().environment(\.palette, p) }
  }
}
struct ThemeBackground: View {
  @Environment(\.palette) private var p
  var body: some View {
    ZStack {
      p.paper
      if p.theme == .holo {
        LinearGradient(
          colors: (p.dark
            ? [0x120E26, 0x1C1036, 0x0A1A2B, 0x160F1F] : [0xE6E0FF, 0xFFDDF4, 0xD9F6FF, 0xFFF3D6])
            .map { Color(hex: UInt32($0)) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        Circle().fill(
          AngularGradient(
            colors: [
              .purple.opacity(0.4), .pink.opacity(0.3), .cyan.opacity(0.4), .purple.opacity(0.4),
            ], center: .center)
        ).frame(width: 340, height: 340).blur(radius: 46).offset(x: -80, y: 30)
      }
    }.ignoresSafeArea()
  }
}
struct ThemeCard: ViewModifier {
  @Environment(\.palette) private var p
  func body(content: Content) -> some View {
    content.padding(p.theme == .terminal ? 10 : 14).background(
      p.surface, in: RoundedRectangle(cornerRadius: p.radius)
    )
    .overlay(
      RoundedRectangle(cornerRadius: p.radius).stroke(
        p.line, lineWidth: p.theme == .holo || p.theme == .terminal ? 1 : 3)
    )
  }
}
extension View { func themeCard() -> some View { modifier(ThemeCard()) } }
struct ThemeButtonStyle: ButtonStyle {
  @Environment(\.palette) private var p
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.padding(.horizontal, p.theme == .terminal ? 10 : 16).padding(.vertical, 12)
      .background(
        p.theme == .terminal ? p.accent : p.ink,
        in: RoundedRectangle(cornerRadius: p.theme == .holo ? 24 : 0)
      )
      .foregroundStyle(p.paper).opacity(configuration.isPressed ? 0.65 : 1)
  }
}
struct ThemeHeader: View {
  let title: String
  var importing: (() -> Void)? = nil
  @Environment(\.palette) private var p
  @State private var settings = false
  let remote: RemoteModel
  let library: LibraryModel
  var body: some View {
    HStack(spacing: 8) {
      if p.theme == .holo {
        RoundedRectangle(cornerRadius: 9).fill(
          AngularGradient(colors: [.purple, .pink, .cyan, .purple], center: .center)
        ).frame(width: 28, height: 28)
      }
      Text(
        p.theme == .terminal
          ? "~/" + title.lowercased() : p.theme == .holo ? title : title.uppercased()
      ).font(
        p.font(p.theme == .manga ? 32 : 14, title: p.theme == .manga)
      ).lineLimit(1).minimumScaleFactor(0.6)
      Spacer()
      if let importing {
        icon("plus", label: "Importer des fichiers CBZ", action: importing).accessibilityIdentifier(
          "importCBZ")
      }
      icon(p.theme == .brutal ? "line.3.horizontal" : "slider.horizontal.3", label: "Réglages") {
        settings = true
      }
    }.frame(minHeight: 52).padding(.horizontal, p.theme == .brutal ? 14 : 0)
      .overlay(alignment: .bottom) {
        if p.theme == .brutal { Rectangle().fill(p.ink).frame(height: 3) }
      }
      .sheet(isPresented: $settings) {
        ThemeHost { SettingsView(remote: remote, library: library) }.presentationCornerRadius(
          p.theme == .holo ? 28 : p.theme == .manga ? 8 : 0)
      }
  }
  private func icon(_ name: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Group {
        if p.theme == .terminal {
          Text(name == "plus" ? "[+]" : "[:]").font(p.font(14)).foregroundStyle(p.accent)
        } else {
          Image(systemName: name)
        }
      }.frame(width: 42, height: 42)
        .background(
          p.surface,
          in: RoundedRectangle(cornerRadius: p.theme == .brutal || p.theme == .terminal ? 0 : 22)
        )
        .overlay(
          RoundedRectangle(cornerRadius: p.theme == .brutal || p.theme == .terminal ? 0 : 22)
            .stroke(
              p.line, lineWidth: p.theme == .holo || p.theme == .terminal ? 1 : 3))
    }.accessibilityLabel(label).buttonStyle(.plain)
  }
}
struct SlantedTab: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: 7, y: 0))
      p.addLine(to: CGPoint(x: r.maxX, y: 0))
      p.addLine(to: CGPoint(x: r.maxX - 7, y: r.maxY))
      p.addLine(to: CGPoint(x: 0, y: r.maxY))
      p.closeSubpath()
    }
  }
}
struct ThemeTabBar: View {
  @Binding var selection: Int
  let count: Int
  @Environment(\.palette) private var p
  var body: some View {
    if p.theme == .terminal {
      HStack(spacing: 0) {
        ForEach(0..<3) { i in
          Button {
            selection = i
          } label: {
            Text(
              (selection == i ? "> " : "  ") + ["biblio", "explorer", "activité"][i]
                + (i == 2 && count > 0 ? " (\(count))" : "")
            )
            .font(p.font(12)).lineLimit(1).minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            .foregroundStyle(selection == i ? p.paper : p.ink)
            .background(selection == i ? p.accent : p.surface)
          }.buttonStyle(.plain).accessibilityIdentifier("tab-\(i)")
            .accessibilityLabel(["Bibliothèque", "Explorer", "Activité"][i])
            .accessibilityAddTraits(selection == i ? .isSelected : [])
        }
      }.overlay(alignment: .top) { Rectangle().fill(p.line).frame(height: 1) }
        .background(p.surface.ignoresSafeArea(edges: .bottom))
    } else {
      HStack(spacing: p.theme == .brutal ? 0 : p.theme == .holo ? 4 : 8) {
        ForEach(0..<3) { i in
          Button {
            selection = i
          } label: {
            HStack(spacing: 5) {
              if p.theme == .holo {
                Image(systemName: ["books.vertical", "safari", "arrow.down.circle"][i]).font(
                  .system(size: 16))
              }
              Text(
                p.theme == .holo
                  ? ["Biblio", "Explorer", "Activité"][i] : ["BIBLIO", "EXPLORER", "ACTIVITÉ"][i]
              ).font(p.font(p.theme == .manga ? 17 : 12, title: p.theme == .manga)).fontWeight(
                .bold)
              if i == 2 && count > 0 {
                Text("\(count)").font(.system(size: 10, weight: .bold)).padding(4).background(
                  p.theme == .manga ? p.paper : p.accent, in: Capsule()
                ).foregroundStyle(p.theme == .manga ? p.ink : Color.white)
              }
            }.frame(maxWidth: .infinity, minHeight: p.theme == .holo ? 50 : 48).contentShape(
              Rectangle()
            )
            .foregroundStyle(
              i == selection
                ? (p.theme == .holo || p.theme == .manga ? Color.white : p.paper)
                : (p.theme == .manga ? p.paper : p.ink)
            )
            .background {
              if i == selection {
                if p.theme == .holo {
                  Capsule().fill(p.gradient)
                } else if p.theme == .manga {
                  SlantedTab().fill(p.accent)
                } else {
                  p.ink
                }
              }
            }
            .overlay(alignment: .leading) {
              if p.theme == .brutal && i > 0 { Rectangle().fill(p.ink).frame(width: 3) }
            }
          }.buttonStyle(.plain).accessibilityIdentifier("tab-\(i)").accessibilityLabel(
            ["Bibliothèque", "Explorer", "Activité"][i]
          ).accessibilityAddTraits(i == selection ? .isSelected : [])
        }
      }.padding(p.theme == .holo ? 7 : p.theme == .manga ? 8 : 0)
        .background(
          p.theme == .manga ? p.ink : p.theme == .holo ? p.paper.opacity(0.7) : p.paper,
          in: RoundedRectangle(cornerRadius: p.theme == .holo ? 33 : 0)
        )
        .overlay(
          RoundedRectangle(cornerRadius: p.theme == .holo ? 33 : 0).stroke(
            p.line, lineWidth: p.theme == .holo ? 1 : p.theme == .brutal ? 3 : 0)
        )
        .shadow(color: p.theme == .holo ? .purple.opacity(0.15) : .clear, radius: 15, y: 8)
        .background {
          if p.theme != .holo {
            (p.theme == .manga ? p.ink : p.paper).ignoresSafeArea(edges: .bottom)
          }
        }
        .padding(.horizontal, p.theme == .holo ? 18 : 0).padding(.bottom, p.theme == .holo ? 8 : 0)
    }
  }
}

struct ThemedNavigation: ViewModifier {
  let title: String
  @Environment(\.dismiss) private var dismiss
  @Environment(\.palette) private var p
  func body(content: Content) -> some View {
    content.toolbar(.hidden, for: .navigationBar).safeAreaInset(edge: .top, spacing: 0) {
      HStack {
        Button {
          dismiss()
        } label: {
          Group {
            if p.theme == .terminal {
              Text("[<]").font(p.font(14)).foregroundStyle(p.accent)
            } else {
              Image(systemName: "arrow.left")
            }
          }.frame(width: 44, height: 44)
        }.accessibilityLabel("Retour").accessibilityIdentifier("routeBack")
        Text(
          p.theme == .terminal
            ? "~/" + title.lowercased() : p.theme == .holo ? title : title.uppercased()
        ).font(p.font(18, title: true)).lineLimit(
          1)
        Spacer()
      }.padding(.horizontal, 8).foregroundStyle(p.ink).background(
        p.paper.opacity(p.theme == .holo ? 0.7 : 1))
    }
  }
}
extension View {
  func themedNavigation(_ title: String) -> some View { modifier(ThemedNavigation(title: title)) }
}

/// Use the terminal header on library detail routes without changing other themes.
struct TerminalNavigation: ViewModifier {
  let title: String
  @Environment(\.palette) private var p
  func body(content: Content) -> some View {
    if p.theme == .terminal { content.themedNavigation(title) } else { content }
  }
}

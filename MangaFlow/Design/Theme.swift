import SwiftUI
import UIKit

@Observable @MainActor
final class ThemeSettings {
    var appearance: String { didSet { UserDefaults.standard.set(appearance, forKey: "appAppearance") } }
    var covers: Bool { didSet { UserDefaults.standard.set(covers, forKey: "showLibraryCovers") } }
    var scheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    init() {
        let saved = UserDefaults.standard.string(forKey: "appAppearance") ?? "system"
        appearance = ["system", "light", "dark"].contains(saved) ? saved : "system"
        covers = UserDefaults.standard.object(forKey: "showLibraryCovers") as? Bool ?? true
        UserDefaults.standard.removeObject(forKey: "appTheme")
    }
}
struct ThemePalette {
    let dark: Bool
    var ink: Color { Color(hex: dark ? 0xF2F2EF : 0x1A1A1A) }
    var paper: Color { Color(hex: dark ? 0x121211 : 0xF6F6F4) }
    var surface: Color { Color(hex: dark ? 0x1E1E1C : 0xFFFFFF) }
    var accent: Color { Color(hex: dark ? 0x86AAF2 : 0x2F62C8) }
    var muted: Color { Color(hex: dark ? 0xA6A6A0 : 0x6B6B6B) }
    var line: Color { Color(hex: dark ? 0x2F2F2C : 0xE6E6E2) }
    var chip: Color { Color(hex: dark ? 0x2A2A27 : 0xEFEFEC) }
    var dotOff: Color { Color(hex: dark ? 0x5A5A54 : 0xC9C9C5) }
    var green: Color { Color(hex: dark ? 0x6CC487 : 0x2F7A45) }
    var danger: Color { Color(hex: dark ? 0xF08A7A : 0xB4321F) }
    var radius: CGFloat { 20 }
    func font(_ size: CGFloat, title: Bool = false) -> Font {
        // Dynamic Type keeps the mockup's hierarchy without fixing row heights.
        .system(size: UIFontMetrics(forTextStyle: title ? .title3 : .body).scaledValue(for: size), weight: title ? .semibold : .regular)
    }
}
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}
private struct PaletteKey: EnvironmentKey { static let defaultValue = ThemePalette(dark: false) }
extension EnvironmentValues {
    var palette: ThemePalette { get { self[PaletteKey.self] } set { self[PaletteKey.self] = newValue } }
}
struct ThemeHost<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: () -> Content
    var body: some View {
        let p = ThemePalette(dark: scheme == .dark)
        content().environment(\.palette, p).font(p.font(15)).foregroundStyle(p.ink).tint(p.accent)
            .background(p.paper.ignoresSafeArea())
    }
}
struct ThemeBackground: View {
    @Environment(\.palette) private var p
    var body: some View { p.paper.ignoresSafeArea() }
}
struct ThemeCard: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content.padding(16).background(p.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(p.line, lineWidth: 1))
    }
}
extension View { func themeCard() -> some View { modifier(ThemeCard()) } }
struct ThemeButtonStyle: ButtonStyle {
    @Environment(\.palette) private var p
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(p.font(15, title: true)).padding(.horizontal, 18).padding(.vertical, 12)
            .background(p.accent, in: Capsule()).foregroundStyle(p.dark ? Color.black : Color.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
struct RoundIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var p
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 18, weight: .regular))
            .frame(width: 44, height: 44).background(p.surface, in: Circle())
            .overlay(Circle().stroke(p.line, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
struct ThemeHeader: View {
    let title: String
    var importing: (() -> Void)? = nil
    var search: (() -> Void)? = nil
    var settingsImport: (() -> Void)? = nil
    let remote: RemoteModel
    let library: LibraryModel
    @State private var settings = false
    @State private var pendingImport = false
    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            if let search { RoundIconButton(symbol: "magnifyingglass", label: "Rechercher dans la bibliothèque", action: search) }
            if let importing { RoundIconButton(symbol: "plus", label: "Importer des fichiers CBZ", action: importing).accessibilityIdentifier("importCBZ") }
            RoundIconButton(symbol: "gearshape", label: "Réglages") { settings = true }.accessibilityIdentifier("openSettings")
        }.sheet(isPresented: $settings, onDismiss: {
            if pendingImport { pendingImport = false; settingsImport?() }
        }) {
            ThemeHost {
                SettingsView(remote: remote, library: library, onImport: settingsImport == nil ? nil : {
                    pendingImport = true; settings = false
                })
            }.presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
    }
}
struct ThemedNavigation: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content.toolbar(.hidden, for: .navigationBar).safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                RoundIconButton(symbol: "arrow.left", label: "Retour") { dismiss() }.accessibilityIdentifier("routeBack")
                Text(title).font(p.font(18, title: true)).lineLimit(1)
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 8).background(p.paper)
        }
    }
}
extension View { func themedNavigation(_ title: String) -> some View { modifier(ThemedNavigation(title: title)) } }

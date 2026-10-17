import SwiftUI

@main
struct MangaFlowApp: App {
    @State private var library = LibraryModel()
    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .preferredColorScheme(.dark)
                .tint(FlowStyle.accent)
                .onOpenURL { library.importCBZ($0) }
                .task {
                    #if DEBUG
                    let arguments = ProcessInfo.processInfo.arguments
                    if let index = arguments.firstIndex(of: "-import"), arguments.indices.contains(index + 1), !library.isBusy {
                        library.importCBZ(URL(fileURLWithPath: arguments[index + 1]))
                    }
                    #endif
                }
        }
    }
}

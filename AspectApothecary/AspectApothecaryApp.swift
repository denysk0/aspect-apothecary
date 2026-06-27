import SwiftData
import SwiftUI

@main
struct AspectApothecaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: GameSave.self)
    }
}

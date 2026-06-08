import SwiftUI

@main
struct VideoSlicerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 740, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}

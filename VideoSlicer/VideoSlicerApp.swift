import SwiftUI

@main
struct VideoSlicerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 740, minHeight: 640)
        }
        .windowResizability(.contentSize)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Slice", systemImage: "scissors") }
            ConvertView()
                .tabItem { Label("Convert", systemImage: "film.stack") }
        }
    }
}

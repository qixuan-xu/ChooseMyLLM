import SwiftUI

@main
struct ChooseMyLLMApp: App {
    @State private var hasFinishedWelcome = false

    var body: some Scene {
        Window("Welcome to \(AppConfiguration.displayName)", id: "welcome") {
            StartupView(hasFinishedWelcome: $hasFinishedWelcome)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(hasFinishedWelcome ? .suppressed : .presented)

        Window(AppConfiguration.displayName, id: "main") {
            MainWindowContent()
        }
        .defaultSize(width: 960, height: 700)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(hasFinishedWelcome ? .presented : .suppressed)
    }
}

private struct StartupView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var hasFinishedWelcome: Bool

    var body: some View {
        WelcomePage()
            .containerBackground(.clear, for: .window)
            .task {
                // A brief brand introduction, not a simulated loading operation.
                do {
                    try await Task.sleep(for: .seconds(AppConfiguration.splashDuration))
                } catch {
                    return
                }
                guard !hasFinishedWelcome else { return }
                hasFinishedWelcome = true
                openWindow(id: "main")
            }
    }
}

private struct MainWindowContent: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        MainView()
            .frame(minWidth: 800, minHeight: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // Keep the splash visible until the main content has appeared.
                dismissWindow(id: "welcome")
            }
    }
}

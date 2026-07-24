import SwiftUI

@main
struct PawMateApp: App {
    @UIApplicationDelegateAdaptor(PushCoordinator.self) var pushCoordinator

    var body: some Scene {
        WindowGroup {
            RootRouterView()
        }
    }
}

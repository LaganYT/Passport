import SwiftUI

@main
struct PassportApp: App {
    @State private var passport = Passport()

    var body: some Scene {
        Window("Passport", id: "main") {
            ContentView(passport: passport)
                .frame(width: 460)
        }
        .windowResizability(.contentSize)
    }
}

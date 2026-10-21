import SwiftUI

struct ContentView: View {
    let passport: Passport
    @State private var confirmRemove = false
    @State private var showLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Passport").font(.title.weight(.semibold))
                Text("Runs Windows Steam games in a Linux engine, so Easy Anti-Cheat's Linux support starts.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(passport.checks) { check in
                    HStack(spacing: 10) {
                        Image(systemName: symbol(check.state)).foregroundStyle(color(check.state)).frame(width: 18)
                        Text(check.title)
                        Spacer()
                        Text(check.detail).foregroundStyle(.secondary).multilineTextAlignment(.trailing).lineLimit(2)
                    }
                    .padding(.vertical, 8)
                    if check.id != passport.checks.last?.id { Divider() }
                }
            }

            if let note = note {
                HStack {
                    Text(note).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    if passport.steamRunning && !passport.busy {
                        Button("Quit Steam") { passport.quitSteam() }
                    }
                }
            }

            HStack {
                if passport.busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Remove…", role: .destructive) { confirmRemove = true }
                    .disabled(passport.busy || passport.steamRunning)
                Button(passport.installed ? "Update" : "Install") { showLog = true; passport.install() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canInstall)
            }

            DisclosureGroup("Log", isExpanded: $showLog) {
                LogView(text: passport.log)
            }

            HStack {
                Button("Open Passport's log") { passport.reveal("passport.log") }
                Button("Open folder") { passport.reveal("") }
                Spacer()
            }
            .buttonStyle(.link).font(.callout)
        }
        .padding(20)
        .confirmationDialog("Remove Passport from Steam?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { showLog = true; passport.uninstall() }
        } message: {
            Text("Steam goes back to how it was. The downloaded engine stays in Passport's folder.")
        }
    }

    private var canInstall: Bool {
        !passport.busy && !passport.steamRunning && passport.blocked == nil
    }

    private var note: String? {
        if let result = passport.result, !passport.busy { return result }
        if let blocked = passport.blocked { return blocked }
        if passport.steamRunning { return "Quit Steam to install or remove Passport." }
        if passport.installed { return "Pick Passport in a game's Properties, Compatibility." }
        return nil
    }

    private func symbol(_ state: Passport.State) -> String {
        switch state {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .missing: "circle.dashed"
        }
    }

    private func color(_ state: Passport.State) -> Color {
        switch state {
        case .ok: .green
        case .warning: .orange
        case .missing: .secondary
        }
    }
}

private struct LogView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? "Nothing yet." : text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("end")
            }
            .frame(height: 160)
            .onChange(of: text) { proxy.scrollTo("end", anchor: .bottom) }
        }
        .padding(.top, 6)
    }
}
